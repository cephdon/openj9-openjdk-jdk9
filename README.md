# OpenJ9 Build README

## How to Build OpenJ9 on Linux

1. Download and install *jdk8* from http://java.sun.com/javase/downloads/index.jsp
1. Clone the OpenJ9 repository

  > git clone git@github.ibm.com:runtimes/openj9.git

1. Get all of the J9 sources:

  > cd openj9
  
  > bash get_source.sh --with-j9

1. Run `configure` script:

  > bash configure --with-j9
  
  **Note:** If *configure* cannot find the *jdk8*, you might need to use the *configure* option *--with-boot-jdk*.
  
  **e.g:** 
  
  > bash configure --with-j9 --with-boot-jdk=/path/to/jdk8
  
1. Compile and build:
  
  > make all
