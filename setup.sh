if [ ! -d "$HOME/bin" ]; then
  echo 'creating directory ${HOME}/bin' 
  mkdir $HOME/bin
fi
svn checkout http://cssjanus.googlecode.com/svn/trunk/ $HOME/bin/cssjanus
echo 'checkout cssjanus at '$HOME'/bin/cssjanus'
