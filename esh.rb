require "readline"

class Esh
  def initialize()
    stty_save = `stty -g`.chomp
    trap("INT") { system "stty", stty_save; exit }
    #trap("INT", "SIG_IGN")
    @scope = Proc.new {}

    Readline.completion_proc = Proc.new do |s|
      (methods+Dir[s+'*']).grep(/^#{Regexp.escape(s)}/)
    end
  end

  def shell_eval(line)
    begin
      if line.match /^cd$/
        Dir.chdir
      elsif line.match /^cd /
        d = line[3, line.length]
        d = File.expand_path(d)
        p d
        Dir.chdir d
      else
        result=eval(line, @scope.binding)
        if !result.nil?
          puts(result)
        end
      end
    rescue SyntaxError, NameError => e
      line = "\"" + line.split(" ").join("\" + \" ") + "\""
      line = eval(line)
      puts `#{line}`
    rescue StandardError => e
      puts "FAIL"
      p e
    end
  end
  
  def repl()
    while line = Readline.readline("#{Dir.pwd}$ ", true)
      Readline::HISTORY.pop if /^\s*$/ =~ line

      begin
        if Readline::HISTORY[Readline::HISTORY.length-2] == line
          Readline::HISTORY.pop
        end
      rescue IndexError
      end
  
      if line.include?(';')
        parts = line.split(';')
        for part in parts
          shell_eval(part)
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
