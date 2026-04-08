@echo on
cd /d %~dp0

git init
git add .
git commit -m "upload files"
git branch -M main

git remote remove origin
git remote add origin https://github.com/quantaum2-star/asdasdsa.git

git push -u origin main

pause