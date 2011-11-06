scope = Proc.new {}

while true
  "#{Dir.pwd}> ".display
  gets.each do |l|
    l = l.chomp
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
end
