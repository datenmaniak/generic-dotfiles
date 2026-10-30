mkdir -p i ~/.local/share/fonts
mv *.ttf ~/.local/share/fonts
fc-cache -fv ~/.local/share/fonts
