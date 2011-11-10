# Esh (ʃ) 

A programming friendly Ruby/shell mashup with a syntax suitable for both executing shell tasks and writing functions.

### Reasoning:

- We're tired of switching back and forth between repls and shells for common tasks.

- Ruby, because it is a popular modern language, and its Perl influence makes it compatible with many existing Unix shell conventions.

- Not pure Ruby, because a shell should support our shared muscle memory for things like `cd ..`

### Ruby on OS X is compiled against a fake readline library.  

If you're on OS X, everything will be better if you do one of these things:

#### If you use rvm:

    $ brew install readline
    $ rvm install 1.8.7 -C --with-readline-dir=/opt/local/

#### If you don't use rvm:

http://jorgebernal.info/2009/11/18/fixing-snow-leopard-ruby-readline/

### Examples:

    $ 1+2
    3
    $ ls
    README esh.rb
    $ x = "."
    $ ls #{x}
    README esh.rb
    $ ls | split("\n").size
    2
    $ [1,2,3]
    [1, 2, 3]
    $ ['a', 'b', 'c'].join("\n")
    "a\nb\nc"
    $ puts ['a', 'b', 'c'].join("\n")
    a
    b
    c
    $ ['a', 'b', 'c'].join("\n") | wc
           2       3       5
    $ jobs
    []
    $ ping google.com
    PING google.com (74.125.224.145): 56 data bytes
    64 bytes from 74.125.224.145: icmp_seq=0 ttl=52 time=17.930 ms
    64 bytes from 74.125.224.145: icmp_seq=1 ttl=54 time=20.599 ms
    ^Z$ jobs
    [74583]
    $ fg
    64 bytes from 74.125.224.145: icmp_seq=2 ttl=54 time=22.005 ms
    64 bytes from 74.125.224.145: icmp_seq=3 ttl=54 time=20.097 ms
    64 bytes from 74.125.224.145: icmp_seq=4 ttl=54 time=23.263 ms
    ^C
    --- google.com ping statistics ---
    5 packets transmitted, 5 packets received, 0.0% packet loss
    round-trip min/avg/max/stddev = 17.930/20.779/23.263/1.805 ms
    $