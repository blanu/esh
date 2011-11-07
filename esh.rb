require "readline"

stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }
#trap("INT", "SIG_IGN")
scope = Proc.new {}

Readline.completion_proc = Proc.new do |s|
  (methods+Dir[s+'*']).grep(/^#{Regexp.escape(s)}/)
end

def shellEval(line)
  begin
    if line.match /^cd$/
      Dir.chdir
    elsif line.match /^cd /
      d = l[3, line.length]
      d = File.expand_path(d)
      p d
      Dir.chdir d
    else
      puts(eval(line, scope.binding))
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
      shellEval(part)
    end
  else
    shellEval(line)
  end
end

puts ''
