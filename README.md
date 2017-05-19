# OpenJ9 Build README

## How to Build OpenJ9 on Linux

1. Download and install *IBM SDK for Java 8* from Java Information Manager: http://w3.hursley.ibm.com/java/jim/ibmsdks/java80/index.html
1. Clone the OpenJ9 repository

  > git clone git@github.ibm.com:runtimes/openjdk-jdk9.git

1. Get all of the J9 sources:

  > cd openj9
  
  > bash get_source.sh --with-j9

1. Run `configure` script:

  > bash configure --with-j9
  
  **Note:** If *configure* cannot find the *IBM SDK for Java 8*, you might need to use the *configure* option *--with-boot-jdk*.
  
  **e.g:** 
  
  > bash configure --with-j9 --with-boot-jdk=/path/to/ibm/sdk8
  
1. Compile and build:
  
  > make all
