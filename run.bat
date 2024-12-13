@echo off
echo Starting Hexo blog deployment...
call hexo clean
call hexo g
call hexo s
pause 