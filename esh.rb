#! /usr/bin/env ruby
require "readline"
require "open4"
require "etc"
require "socket"
require "pp"

class Esh
  def initialize()
    @active_pid = nil
    stty_save = `stty -g`.chomp
    #trap("INT") { system "stty", stty_save }
    trap("INT") do
      if !@active_pid.nil?
        Process.kill "SIGINT", @active_pid
      end
    end
    @scope = Proc.new {}
    @_ = nil

    Readline.completion_proc = Proc.new do |s|
      (methods+Dir[s+'*']).grep(/^#{Regexp.escape(s)}/)
    end
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
        if line.match /^cd$/
          Dir.chdir
        elsif line.match /^cd /
          Dir.chdir File.expand_path(line.split(" ", 2)[1].strip)
        else
          result = eval(line, @scope.binding)
          if mode == :PIPE
            @_ = result
            eval("_ = \"#{result}\"", @scope.binding)
          else
            if !result.nil?
              pp result
            end
          end
        end
      rescue SyntaxError, NameError => e
        line = "\"" + line.gsub("\"", "\\\"") + "\""
        line = eval(line, @scope.binding)

        if mode == :FORK
          pid = Process.fork do
            exec line
          end

          Process.waitpid pid
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
            eval("_ = \"#{result}\"", @scope.binding)
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
    begin
      history = File.open(File.expand_path("~/.esh_history")).readlines
    rescue
      history = []
    end
    Readline::HISTORY.push(*history)
    while line = Readline.readline("#{Etc.getlogin}@#{Socket.gethostname.split(".")[0]}:#{Dir.pwd.sub(ENV["HOME"], "~")}$ ", true)
      history << line

      if ((/^\s*$/ =~ line) ||
          (history.length > 1 && history[history.length-2] == line))
        Readline::HISTORY.pop
        history.pop
      else
        File.open(File.expand_path("~/.esh_history"), "ab+") do |f|
          f << line + "\n"
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
