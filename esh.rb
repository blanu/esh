require "readline"
require "open4"

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

  def shell_eval(line, fork=true)
    shell_attempt() do
      begin
        if line.match /^cd$/
          Dir.chdir
        elsif line.match /^cd /
          Dir.chdir File.expand_path(line.split(" ", 2)[1].strip)
        else
          result = eval(line, @scope.binding)
          if !result.nil?
            puts(result)
          end
        end
      rescue SyntaxError, NameError => e
        line = "\"" + line.split(" ").join("\" + \" ") + "\""
        line = eval(line, @scope.binding)
        if fork
          @active_pid = Process.fork do
            shell_attempt do
              exec line
            end
          end
          Process.waitpid @active_pid
        else
          status = Open4.open4(line) do |pid, stdin, stdout, stderr|
            @active_pid = pid
            result = stdout.read
          end
          eval("_ = \"#{result}\"", @scope.binding)
        end
        @active_pid = nil
      end
    end
  end

  def repl()
    history = []
    while line = Readline.readline("#{Dir.pwd}$ ", true)
      history << line
      Readline::HISTORY.pop if /^\s*$/ =~ line
      history.pop if /^\s*$/ =~ line

      if history.length > 1 && history[history.length-2] == line
        Readline::HISTORY.pop
        history.pop
      end

      if line.include?(';')
        parts = line.split(';')
        for part in parts
          shell_eval(part)
        end
      elsif line.include?(' | ')
        parts = line.split(' | ')
        for part in parts
          shell_eval(part, false)
        end
      else
        shell_eval(line)
      end
    end

    puts ''
  end
end

esh = Esh.new()
esh.repl()
