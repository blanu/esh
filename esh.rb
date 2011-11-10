#! /usr/bin/env ruby
require "readline"
require "open4"
require "etc"
require "socket"
require "pp"
require "irb"
require "irb/completion"

class Esh
  attr_reader :jobs

  def initialize()
    @active_pid = nil
    @jobs = []
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
    Readline.completion_append_character = nil
    Readline.completion_proc = Proc.new do |s|
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
      s = File.expand_path(s) + last
      Dir[s+'*'].map do |x|
        if File.directory? x
          x + "/"
        else
          x
        end
      end.grep(/^#{Regexp.escape(s)}/).select { |x| x != s + "/" } + irb_completions
    end
  end

  def bg(*a)
    job = a[0] || -1
    pid = @jobs[job]
    Process.kill "CONT", pid
    return nil
  end

  def fg(*a)
    job = a[0] || -1
    pid = @jobs[job]
    bg job
    @active_pid = pid
    Process.waitpid @active_pid, Process::WUNTRACED
    @jobs.delete @active_pid
    return nil
  end

  def shell_attempt
    begin
      yield
    rescue Errno::ENOENT => e
      puts e.message
    rescue StandardError => e
      puts "FAIL"
      p e
    end
  end

  # modes: :PIPE, :ENDPIPE, :FORK
  def shell_eval(line, mode=:FORK)
    shell_attempt() do
      begin
        if line.match /^cd\s*$/
          Dir.chdir
        elsif line.match /^cd\s/
          Dir.chdir File.expand_path(line.split(" ", 2)[1].strip)
        else
          result = @workspace.evaluate(nil, line)
          if mode == :PIPE
            @_ = result
            @workspace.evaluate(nil, "_ = \"#{result}\"")
          else
            if !result.nil?
              pp result
            end
          end
        end
      rescue SyntaxError, NameError => e
        line = "\"" + line.gsub("\"", "\\\"") + "\""
        line = @workspace.evaluate(nil, line)

        if mode == :FORK
          @active_pid = Process.fork do
            exec line
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
          if mode == :PIPE
            @_ = result
            @workspace.evaluate(nil, "_ = \"#{result}\"")
          else
            if !result.nil?
              puts(result)
            end
          end
        end
        @active_pid = nil
      end
    end
  end

  def repl()
    history = []
    begin
      File.open(File.expand_path("~/.esh_history")) do |f|
        history = f.readlines.map { |x| x.chomp }.select { |x| !x.empty? }
      end
    rescue
    end
    Readline::HISTORY.push(*history)
    while line = Readline.readline("#{Etc.getlogin}@\e[31m#{Socket.gethostname.split(".")[0]}\e[0m:#{Dir.pwd.sub(ENV["HOME"], "~")}$ ", true)
      history << line

      if ((/^\s*$/ =~ line) ||
          (history.length > 1 && history[history.length-2] == line))
        Readline::HISTORY.pop
        history.pop
      else
        File.open(File.expand_path("~/.esh_history"), "ab+") do |f|
          f << line + "\n"
          f.flush
        end
      end

      @_ = nil

      if line.include?(';')
        parts = line.split(';')
        for part in parts
          @_ = nil
          shell_eval(part)
        end
      elsif line.include?(' | ')
        parts = line.split(' | ')
        for part in parts.slice(0,parts.size()-1) # Eval all but last part, piping result into next part
          shell_eval(part, :PIPE)
        end
        shell_eval(parts[parts.size()-1], :ENDPIPE) # Eval last part and print result
      else
        shell_eval(line)
      end
    end

    puts ''
  end
end

esh = Esh.new()
esh.repl()
