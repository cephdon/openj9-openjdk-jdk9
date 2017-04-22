/*===========================================================================
 * Licensed Materials - Property of IBM
 * "Restricted Materials of IBM"
 * 
 * IBM SDK, Java(tm) Technology Edition, v9
 * (C) Copyright IBM Corp. 2016, 2016. All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure
 * restricted by GSA ADP Schedule Contract with IBM Corp.
 *===========================================================================
 */
package com.ibm.jvm.io;


class ZipInitialization{

 /**
 * Returns the java.util.zip.ZipFile InputStream class.
 */
 public static Class<?> getZipFileInputStreamClass(){

        Class<?> c;

        try {
            c = Class.forName("java.util.zip.ZipFile$ZipFileInputStream");
        } catch (ClassNotFoundException e) {
            c = null;
        }
        return c ;

  }

}
