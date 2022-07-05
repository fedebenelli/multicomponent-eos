#!/bin/sh
FPM=$(which fpm || ./fpm)
DESIRED_COVERAGE=90

DID_TEST=0

echoerr() { echo -e "$@" 1>&2; }

green() {
    echo -e "\e[1;32m$@\e[m"
}

red() {
    echo -e "\e[1;31m$@\e[m"
}

install() {
    wget https://github.com/fortran-lang/fpm/releases/download/v0.6.0/fpm-0.6.0-linux-x86_64 -O fpm
    chmod +x fpm
}

run_test() {
    $FPM clean
    DID_TEST=1
    echo Checking tests files names...
    NAMING_ERRORS=0
    for file in $(find test/*f90); do
        filename="$(basename $file)"
        prefix="$(echo $filename | cut -d '_' -f1)"

        if [ "$prefix" = "test" ]; then
            green "$file [OK]"
        else
            NAMING_ERRORS=$((NAMING_ERRORS + 1))
            red "$file [X]"
        fi
    done

    [ $NAMING_ERRORS -ge 1 ] && echoerr "There are wrongly named files in the test directory"

    echo Running tests...
    $FPM test --flag "--coverage"
}

run_coverage() {
    gcovr --exclude "build" --exclude "test" --fail-under-branch 90
}

resumee() {
    [ $DID_TEST = 1 ] &&
        echo There has been $NAMING_ERRORS test naming errors
}


case $1 in
    "install")  install;;
    "test") run_test;;
    "coverage") run_coverage;;
    *)
        #install
        run_test
        run_coverage;;
esac

resumee
