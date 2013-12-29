#! /usr/bin/env ruby
# -*- coding: utf-8 -*-
require "readline"
require "open4"
require "etc"
require "socket"
require "pp"
require "irb"
require "irb/completion"
begin
  require "~/.esh.rb"
rescue LoadError
end

$histfile = "~/.zhistory"

class Esh
  class << self
    def const_missing(name)
      if ENV.has_key? name.to_s
        return ENV[name.to_s]
      end
      super.const_missing name
    end
  end

  attr_reader :jobs

  def initialize()
    @active_pid = nil
    @jobs = []
    @zhistory = false
    stty_save = `stty -g`.chomp
    #trap("INT") { system "stty", stty_save }
    trap("INT") do
      if !@active_pid.nil?
        Process.kill "INT", @active_pid
      end
    end

    trap("TSTP") do
      if !@active_pid.nil?
        Process.kill "TSTP", @active_pid
        @jobs << @active_pid
        @active_pid = nil
      end
    end

    @scope = Proc.new {}
    @_ = nil

    IRB.setup self
    IRB.conf[:MAIN_CONTEXT] = IRB::Irb.new.context
    @workspace = IRB::WorkSpace.new(self, @scope.binding)
    IRB.conf[:MAIN_CONTEXT].workspace = @workspace
    if Readline.respond_to?("basic_word_break_characters=")
      Readline.basic_word_break_characters= " \t\n\"\\'`><=;|&{("
    end
    Readline.completion_proc = Proc.new do |s|
      Readline.completion_append_character = nil
      if s =~ /^\//
        irb_completions = []
      else
        irb_completions = IRB::InputCompletor::CompletionProc.call(s)
      end
      if s =~ /\/$/
        last = "/"
      else
        last = ""
      end
      expanded = File.expand_path(s) + last
      dirs = Dir[expanded+'*'].map do |x|
        if File.directory? x
          x.sub(expanded, s) + "/"
        else
          x.sub(expanded, s)
        end
      end.grep(/^#{Regexp.escape(s)}/)
      bins = path_binaries.grep(/^#{Regexp.escape(s)}/)
      bins + dirs + irb_completions
    end
  end

  def bg(*a)
    job = a[0] || -1
    pid = @jobs[job]
    if pid.nil?
      puts "no such job"
    else
      Process.kill "CONT", pid
    end
    return nil
  end

  def fg(*a)
    job = a[0] || -1
    pid = @jobs[job]
    bg job
    if !pid.nil?
      @active_pid = pid
      Process.waitpid @active_pid, Process::WUNTRACED
      @jobs.delete @active_pid
    end
    return nil
  end

  def method_missing(*args)
    pp args.join(" ")
    name = args[0]
    if ENV.has_key? name.to_s
      return ENV[name.to_s]
    end
    return nil
  end

  def path_binaries
    PATH.split(":").map do |dirname|
      begin
        Dir.entries(dirname).select { |f| File.executable? File.join(dirname, f) }
      rescue
        []
      end
    end.flatten
  end

  def path_find(*a)
    name = a[0]
    PATH.split(":").each do |dirname|
      begin
        dir = Dir.new(dirname)
        dir.each do |f|
          if f == name
            f = File.join(dir.path, f)
            if File.executable? f
              return f
            end
          end
        end
      rescue
      end
    end
    return nil
  end

  def shell_attempt
    begin
      yield
    rescue Errno::ENOENT => e
      puts e.message
    rescue StandardError => e
      puts "#{e.class}: #{e.message}"
      bt = e.backtrace.map do |x|
        "        from #{x}\n"
      end
      puts bt
    end
  end

  # modes: :PIPE, :ENDPIPE, :FORK
  def shell_eval(line, mode=:FORK)
    shell_attempt() do
      result = nil
      command = line.split(" ")[0]
      args = (line.split(" ", 2)[1] || "").strip
      bin = path_find(command)
      # to catch invalid ruby: rescue SyntaxError, NameError => e
      if command == "cd"
        if not args
          Dir.chdir
        else
          Dir.chdir File.expand_path(args)
        end
      elsif bin
        # evaluate as a string, to handle interpolation
        args = "\"" + args.gsub("\"", "\\\"") + "\""
        args = @workspace.evaluate(nil, args)
        args = args.split(" ")

        if mode == :FORK
          @active_pid = Process.fork do
            begin
              exec command, *args
            rescue => e
              puts e.message
            end
          end

          Process.waitpid @active_pid, Process::WUNTRACED
        else
          status = Open4.open4(line) do |pid, stdin, stdout, stderr|
            @active_pid = pid
            if @_ != nil
              stdin.write(@_)
            end
            stdin.close()
            result = stdout.read
          end
          if mode == :ENDPIPE
            if !result.nil?
              puts(result)
            end
          end
        end
        @active_pid = nil
      else
        if mode == :PIPE || mode == :ENDPIPE
          result = @workspace.evaluate(nil, "@_.instance_eval { #{line} }")
        else
          result = @workspace.evaluate(nil, line)
        end
        if mode == :ENDPIPE || mode == :FORK
          if !result.nil?
            pp result
          end
        end
      end
      @_ = result
      @workspace.evaluate(nil, "_ = @_")
    end
  end

  def repl()
    history = []
    begin
      File.open(File.expand_path($histfile)) do |f|
        history = f.readlines.map do |x|
          match = x.match /: (\d+):(\d+);(.*)/
          if match
            @zhistory = true
            timestamp, _, x = match.captures
          end
          x.chomp
        end.select { |x| !x.empty? }
      end
    rescue
    end
    Readline::HISTORY.push(*history)

    while line = Readline.readline("#{Etc.getlogin}@\x01\e[31m\x02#{Socket.gethostname.split(".")[0]}\x01\e[0m\x02:#{Dir.pwd.sub(ENV["HOME"], "~")} ❯ ", true)
      history << line

      if ((/^\s*$/ =~ line) ||
          (history.length > 1 && history[history.length-2] == line))
        Readline::HISTORY.pop
        history.pop
      else
        File.open(File.expand_path($histfile), "ab+") do |f|
          if @zhistory
            f << ": #{Time.now.to_i}:0;"
          end
          f << "#{line}\n"
          f.flush
        end
      end

      if line.include?(';')
        parts = line.split(';')
        for part in parts
          shell_eval(part)
        end
      elsif line.include?(' | ')
        parts = line.split(' | ')
        shell_eval(parts[0], :STARTPIPE) # Eval first part, piping result into next part
        for part in parts.slice(1, parts.size-2) # Eval all but last part, piping previus result in this part and this result into next part
          shell_eval(part, :PIPE)
        end
        shell_eval(parts[parts.size-1], :ENDPIPE) # Eval last part and print result
      else
        shell_eval(line)
      end
    end

    puts ''
  end
end

esh = Esh.new()
esh.repl()
