/*===========================================================================
 * Licensed Materials - Property of IBM
 * "Restricted Materials of IBM"
 * 
 * IBM SDK, Java(tm) Technology Edition, v9
 * (C) Copyright IBM Corp. 1992, 2004. All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure
 * restricted by GSA ADP Schedule Contract with IBM Corp.
 *===========================================================================
 */

/*
 * ===========================================================================
 (C) Copyright Sun Microsystems Inc, 1992, 2004. All rights reserved.
 * ===========================================================================
 */

/* 
 *
 * Change activity:
 *
 * Reason  Date     Origin  Description
 * ------  ----     ------  ---------------------------------------------------- 
 * JSE-821 20070102 cwhite  Original - ported from SDK 5.0
 * ===========================================================================
 * Module Information:
 *      
 * DESCRIPTION:
 * Wrapper class used on non ASCII platforms to convert characters, written to
 * output streams, from ASCII (8859_1) to the platform encoding
 * ===========================================================================
 */

package com.ibm.jvm.io;

import java.io.*;
import java.nio.charset.*;
import java.nio.*;
import java.lang.reflect.Field;


/**
 * LocalizedOutputStream is a wrapper class used by JVM classes which write
 * characters to output streams.
 * This class contains a localize method which is passed an OutputStream
 * (normally a FileOutputStream). The method first checks if it
 * is being used on an ASCII platform, if so nothing needs to be done. If
 * not it creates an instance of LocalizedOutputStream containing
 * the original OutputStream and returns the new class to the calling
 * method.
 * Currently this is only used by the Properties.store method.
 */

public final class LocalizedOutputStream extends FilterOutputStream {

    /**
     * The convertor used to convert ASCII characters to platform
     * characters.
     */
    private CharsetEncoder ctb = Charset.defaultCharset().newEncoder();

    /**
     * Static flag used to denote that this class is being executed on
     * a non ASCII platform. Default value of false (ASCII platform)
     * which will disable the localize method. It is set once in the static initializer.
     */
    public static boolean nonASCIIPlatform = false;                             //IBM-zos_ebcdic

    static {
        java.security.AccessController.doPrivileged(
                new java.security.PrivilegedAction<Object>() {
                    public Object run() {
                        nonASCIIPlatform =
                                !System.getProperty("platform.notASCII", "false").equalsIgnoreCase("false");
                        return null;
                    }
                });
    }

    /**
     * Make the constructor private so an instance of this class
     * can't be created directly.
     */
    private LocalizedOutputStream(OutputStream out) {
        super(out);
    }

    /**
     * Convert a single character and write it to the output stream.
     */
    public void write(int c) throws IOException {
        byte bbuf[] = new byte[1];
        char cbuf[] = new char[1];

        cbuf[0] = (char)c;
        ctb.reset();
        ByteBuffer bb = ByteBuffer.wrap(bbuf);
        CharBuffer cb = CharBuffer.wrap(cbuf, 0, 1);
        CoderResult cr = ctb.encode(cb, bb, true);
        cr = ctb.flush(bb);

        out.write(bbuf[0]);
    }

    /**
     * Convert and write the supplied byte array of characters
     * to the wrapped output stream. The number of characters written
     * is determined by the length of the supplied array.
     *
     * @param b The byte array containing the characters.
     */
    public void write(byte b[]) throws IOException {
        write(b, 0, b.length);
    }

    /**
     * Convert and write <code>len</code> bytes from the supplied
     * array, starting at <code>off</code> to the wrapped output stream.
     *
     * @param b   The byte array containing the characters.
     * @param off The start offset into b of the bytes.
     * @param len The number of characters to write from b.
     */
    public void write(byte b[], int off, int len) throws IOException {
        int ep = off+len;

        if ((off | len | (b.length - ep) | ep) < 0)
            throw new IndexOutOfBoundsException();

        for (int i = off ; i < ep ; i++) {
            write(b[i]);
        }
    }

    /**
     * Static method used to determine if a LocalizedOutputStream
     * needs to be wrapped around the supplied OutputStream.
     *
     * Firstly check if we are running on an ASCII platform,
     * if so return the given output stream (do nothing).
     * else check to see if the output stream is a
     * LocalizedOutputStream or a wrapper around a
     * LocalizedOutputStream (e.g. BufferOutputStream) if
     * so, return the supplied output stream.
     *
     * @param in The output stream to be wrapped.
     * @return   The resulting output stream, which may or may not
     *           have been wrapped in a LocalizedOutputStream
     */
    public static OutputStream localize(OutputStream in) {

        if (nonASCIIPlatform) {
            OutputStream os = in;

            /* i should never be null, this is just a
             * safety test.
             */
            while (os != null) {

                /* If we have found a LocalizedOutputStream
                 * either passed in or inside of a wrapper
                 * return the original class we were given.
                 */
                if (os instanceof LocalizedOutputStream) {
                    break;
                } else {
                    /* Is the OutputStream a subclass of;
                     * FilterOutputStream
                     *    If so unwrap the class (get the hidden output stream)
                     *    and continue.
                     * FileOutputStream
                     *    If so wrapper it, convert ASCII -> EBCDIC and return.
                     */

                    Class<?> c = os.getClass();
                    while (c != null &&
                           c != java.io.FileOutputStream.class &&
                           c != FilterOutputStream.class) {
                        c = c.getSuperclass();

                    }

                    if (c == FilterOutputStream.class) {
                        os = LocalizedOutputStream.unwrap((FilterOutputStream)os);
                    } else if (c == java.io.FileOutputStream.class) {
                        return new LocalizedOutputStream(in);
                    } else {
                        break;
                    }

                }
            }
        }
        return in;
    }

    /**
     * Method used to tunnel into a FilterOutputStream and return
     * the output stream it contains.
     *
     * @param fis FilterOutputStream from which the output stream
     *            will be extracted.
     * @return The output stream contained inside of fos.
     */
    public static OutputStream unwrap(FilterOutputStream fos) {                 //IBM-zos_ebcdic
	OutputStream os;
	try {
	    Class<?> cl = fos.getClass();
	    Field f = cl.getField("out");
	    f.setAccessible(true);
	    os = (OutputStream)f.get(fos);
	} catch (Exception e) {
	    os = null;
	}
	return os;
    }

}

