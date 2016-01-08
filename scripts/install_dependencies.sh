#!/bin/bash

function has_exec() {
  which $1 >/dev/null
}

function print_title() {
  tput bold
  echo "#"
  echo "# $@"
  echo "#"
  tput sgr0
}

cd $(dirname ${BASH_SOURCE[0]})/..
[[ -d .dependencies ]] || mkdir .dependencies
cd .dependencies

if ! has_exec jruby ; then
  print_title "Installing JRuby..."
  rvm install jruby
fi

if ! has_exec sass || ! has_exec compass ; then
  print_title "Installing Ruby Sass & Compass..."
  gem install sass compass
fi

if [[ ! -f "$SASSC_BIN" ]]; then
  print_title "Installing SassC..."
  git clone https://github.com/sass/libsass.git
  export SASS_LIBSASS_PATH=$PWD/libsass
  git clone https://github.com/sass/sassc.git
  cd sassc && make && cd ..
  export SASSC_BIN=$PWD/sassc/bin/sassc
fi

if [[ ! -f "$CSSJANUS_BIN" ]]; then
  print_title "Installing CSSJanus..."
  svn checkout http://cssjanus.googlecode.com/svn/trunk/ cssjanus
  export CSSJANUS_BIN=$PWD/cssjanus/cssjanus.py
fi

if [[ ! -f "$CLOSURE_COMPILER_JAR" ]]; then
  print_title "Installing Closure Compiler..."
  curl https://dl.google.com/closure-compiler/compiler-latest.zip > compiler-latest.zip
  unzip -o compiler-latest.zip
  export CLOSURE_COMPILER_JAR=$PWD/compiler.jar
fi

if [[ ! -f "$PNGCRUSH_BIN" ]]; then
  print_title "Installing pngcrush..."
  npm install pngcrush-bin
  export PNGCRUSH_BIN=$PWD/node_modules/pngcrush-bin/cli.js
fi

cd ..
