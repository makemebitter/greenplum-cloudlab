# the following two lines give a two-line status, with the current window highlighted
hardstatus alwayslastline
hardstatus string '%{= kG}[%{G}%H%? %1`%?%{g}][%= %{= kw}%-w%{+b yk} %n*%t%?(%u)%? %{-}%+w %=%{g}][%{B}%m/%d %{W}%C%A%{g}]'

# huge scrollback buffer
defscrollback 5000

# no welcome message
startup_message off

# 256 colors
attrcolor b ".I"
termcapinfo xterm 'Co#256:AB=\E[48;5;%dm:AF=\E[38;5;%dm'
defbce on

# mouse tracking allows to switch region focus by clicking
# mousetrack on

# default windows
screen -t HTOP  1 htop
screen -t SRC  2 bash
screen -t LOG  3 bash
screen -t S1  4 bash
screen -t S2   5 bash
screen -t S3   6 bash
screen -t BG   7 bash
select 0
bind c screen 1 # window numbering starts at 1 not 0
bind 0 select 10

# get rid of silly xoff stuff
bind s split

# layouts
layout autosave on
layout new one
select 1
layout new two
select 1
split
resize -v +8
focus down
select 4
focus up
layout new three
select 1
split
resize -v +7
focus down
select 3
split -v
resize -h +10
focus right
select 4
focus up

layout attach one
layout select one