require "readline"

stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }
#trap("INT", "SIG_IGN")
scope = Proc.new {}

Readline.completion_proc = Proc.new do |s|
  (methods+Dir[s+'*']).grep(/^#{Regexp.escape(s)}/)
end

while l = Readline.readline("#{Dir.pwd}$ ", true)

  Readline::HISTORY.pop if /^\s*$/ =~ l

  begin
    if Readline::HISTORY[Readline::HISTORY.length-2] == l
      Readline::HISTORY.pop
    end
  rescue IndexError
  end

  begin
    if l.match /^cd$/
      Dir.chdir
    elsif l.match /^cd /
      d = l[3, l.length]
      d = File.expand_path(d)
      p d
      Dir.chdir d
    else
      puts(eval(l, scope.binding))
    end
  rescue SyntaxError, NameError => e
    l = "\"" + l.split(" ").join("\" + \" ") + "\""
    l = eval(l)
    puts `#{l}`
  rescue StandardError => e
    puts "FAIL"
    p e
  end
end

puts ''

