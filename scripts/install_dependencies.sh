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

if ! has_exec "${SASSC_BIN:-sassc}" ; then
  export SASSC_BIN=$PWD/sassc/bin/sassc
  if [[ ! -x "$SASSC_BIN" ]]; then
    SASSC_VERSION="3.3.1"

    print_title "Installing SassC..."
    git clone --branch $SASSC_VERSION https://github.com/sass/libsass.git
    export SASS_LIBSASS_PATH=$PWD/libsass
    git clone --branch $SASSC_VERSION https://github.com/sass/sassc.git
    cd sassc && make && cd ..
  fi
fi

if ! has_exec "${CSSJANUS_BIN:-cssjanus.py}" ; then
  export CSSJANUS_BIN=$PWD/cssjanus/cssjanus.py
  if [[ ! -x "$CSSJANUS_BIN" ]]; then
    print_title "Installing CSSJanus to $CSSJANUS_BIN..."
    git clone https://github.com/Khan/cssjanus
    ( cd cssjanus && git checkout 93b83228b8c4a46dd0b836d162983dda413b7eda )
  fi
fi

if ! has_exec pngcrush ; then
  export PNGCRUSH_BIN=$PWD/node_modules/pngcrush-bin/cli.js
  if [[ ! -x "$PNGCRUSH_BIN" ]]; then
    print_title "Installing pngcrush to $PNGCRUSH_BIN..."
    npm install pngcrush-bin
  fi
fi

if [[ ! -f "${CLOSURE_COMPILER_JAR:-.dependencies/compiler.jar}" ]]; then
  export CLOSURE_COMPILER_JAR=$PWD/compiler.jar
  if [[ ! -f "$CLOSURE_COMPILER_JAR" ]]; then
    print_title "Installing Closure Compiler to $CLOSURE_COMPILER_JAR..."
    curl https://dl.google.com/closure-compiler/compiler-latest.zip > compiler-latest.zip
    unzip -o compiler-latest.zip
  fi
fi

cd ..
