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
 *         20060131 cwhite  Original - ported from SDK 5.0
 * ===========================================================================
 * Module Information:
 *      
 * DESCRIPTION: 
 * Wrapper class used on non ASCII platforms to convert characters, read from
 * input streams, from the platform encoding to ASCII (8859_1)
 * ===========================================================================
 */

package com.ibm.jvm.io;

import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.util.zip.ZipInputStream;

/**
 * LocalizedInputStream is a wrapper class used by JVM classes which read 
 * characters from input streams. This is bad practice but something Sun's
 * code still does! It works fine on ASCII platforms as ASCII characters can
 * be cast to UNICODE without problem (in nearly all cases) but this
 * approach will not work on non ASCII platforms.
 * This class contains a localize method which is passed an InputStream
 * (normally a FileInputStream). The method first checks to see if it
 * is being used on as ASCII platform, if so nothing needs to be done. If
 * not it creates an instance of LocalizedInputStream containing
 * the original InputStream and returns the new class to the calling
 * method.
 */

public final class LocalizedInputStream extends FilterInputStream {

    /**
     * The convertor used to convert platform characters to ASCII
     * characters. There is one convertor per LocalizedInputStream
     * as the getDefault method creates a new instance of the default 
     * convertor.
     */
    private CharsetDecoder btc;

    /**
     * Static flag used to denote that this class is being executed on
     * a non ASCII platform. Default value of false (ASCII platform)
     * which will disable the localize method. It is set once in the static initializer.
     */
    public static boolean nonASCIIPlatform = false;

    private static final Class<?> ZipFileInputStreamClass;
    static {
                                                                                //IBM-j9zip
        ZipFileInputStreamClass = ZipInitialization.getZipFileInputStreamClass();  //IBM-j9zip
    }

    /**
     * Protect this LocalizedInputStream from being unwrapped by a 
     * call to getInputStream. This attribute has a specific use,
     * in the Properties.load method, we may pass a LocalizedInputStream
     * to the constructor of InputStreamReader (as load does). The constructor
     * needs to be able to remove any LocalizedInputStreams wrapped around a
     * supplied InputStream to prevent double conversion but in the load
     * method we need the double conversion.
     */
    private boolean allowUnwrapping = true;

    private byte peekBuffer[] = new byte[1000];
    private int peekLength, peekOffset;

    static {
        java.security.AccessController.doPrivileged(
            new java.security.PrivilegedAction<Object>() {
                public Object run () {
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
    private LocalizedInputStream(InputStream in) 
    {
        super(in);
    }

    private void btcInit() {
        boolean foundAscii = false;
        for (peekLength = 0; peekLength < peekBuffer.length;) {
            int c;
            try {
                if (in.available() == 0) break;
                c = in.read();
            } catch (IOException e) {
                break;
            }
            if (c == -1) break;
            peekBuffer[peekLength++] = (byte)c;
            /* Do we have an ascii '#', '=' or '\n' ? */
            if (c == 0x23 || c == 0x3d || c == 0x0a) {
                foundAscii = true; /* yes, flag as ascii */
                break;
            } else {
                /*  Do we have a EBCDIC NL char ? */
                if (c == 0x15) break; /* Yes, break as we have ebcdic */
            }
        }
        
        try {
            if (foundAscii) {
                btc = Charset.forName("8859_1").newDecoder();
            } else {
                btc = Charset.forName("Cp1047").newDecoder();
            }
        } catch (Exception e) {}
    }

    /**
     * Returns the number of bytes that can be read from this input
     * stream without blocking.
     * <p>
     * This method adds the number of bytes in the peekBuffer to
     * the count returned from <code>in.available(n)</code> and
     * returns the result.
     *
     * @return     the number of bytes that can be read from the input stream
     *             without blocking.
     * @exception  IOException  if an I/O error occurs.
     */
    public int available() throws IOException {
        return (peekLength - peekOffset) + in.available();
    }                           

    /**
     * Read a single byte from the input stream and convert it into 
     * ASCII (strictly speaking it returns UNICODE but we are
     * assuming this is the same).
     *
     * @return A single ASCII character read from the wrapped input
     *         stream.
     */
    public int read() throws IOException {
        byte b[] = new byte[1];
        if (read(b) != -1) {
            return b[0] & 0xff;
        } else {
            return -1;
        }
    }

    /**
     * Fill the supplied byte array with characters read in form
     * the wrapped input stream. The number of characters to read
     * is determined by the length of the supplied array.
     *
     * @param b The byte array which will receive the read
     *          characters.
     * @return  The number of bytes actually read, or -1
     *          if no more data read because EOF reached.
     */
    public int read(byte b[]) throws IOException {
        return read(b, 0, b.length);
    }

    /**
     * Read <code>len</code> bytes into the supplied array, starting 
     * at <code>off</code> from the wrapped input stream.
     *
     * @param b   The byte array which will receive the read
     *            characters.
     * @param off The start offset into b to store bytes.
     * @param len The number of characters to read into b.
     * @return    The number of bytes actually read, or -1
     *            if no more data read because EOF reached.
     */
    public int read(byte b[], int off, int len) throws IOException {
        char cbuf[] = new char[len];
        int index;

        if (btc == null) btcInit();

        int count = peekLength - peekOffset;
        if (count > 0) {
            if (count > len) count = len;

            System.arraycopy(peekBuffer, peekOffset, b, off, count);
            
            peekOffset += count;
            if (peekOffset == peekLength) peekBuffer = null;

            if (count < len) {
                int readCount = in.read(b, off+count, len-count);
                if (readCount > 0) count += readCount;
            }
        } else {
            count = in.read(b, off, len);
        }
               
        if (count > 0) {
            btc.reset();
            ByteBuffer bb = ByteBuffer.wrap(b, off, len);
            CharBuffer cb = CharBuffer.wrap(cbuf);
            CoderResult cr = btc.decode(bb, cb, true);
            cr = btc.flush(cb); 

            for (index=0; index < len; index++) {
                b[index+off] = (byte)cbuf[index];
            }
        }

        return count;
    }

    /**
     * Static method used to determine if a LocalizedInputStream 
     * needs to be wrapped around the supplied InputStream.
     *
     * Firstly check if we are running on an ASCII platform,
     * if so return the given input stream (do nothing).
     * else check to see if the input stream is a
     * LocalizedInputStream or a wrapper around a 
     * LocalizedInputStream (e.g. BufferInputStream) if
     * so, return the supplied input stream.
     *
     * @param in The input stream to be wrapped.
     * @return   The resulting input stream, which may or may not
     *           have been wrapped in a LocalizedInputStream
     */
    public static InputStream localize(InputStream in) {

        if (nonASCIIPlatform) {

            InputStream i = in;

            /* i should never be null, this is just a 
             * safety test.
             */
            while (i != null) {

                /* If we have found a LocalizedInputStream
                 * either passed in or inside of a wrapper
                 * return the original class we were given.
                 */
                if (i instanceof LocalizedInputStream) {
                    break;
                } else {
                    /* Is the InputStream a subclass of;
                     * FilterInputStream
                     *    If so unwrap the class (get the hidden input stream)
                     *    and continue.
                     * FileInputStream
                     *    If so wrapper it, convert EBCDIC -> ASCII and return.
                     * ZipInputStream
                     *    If so don't investigate any further, just return,
                     *    ZipInputStream is a subclass of FilterInputStream
                     *    wrapped around a FileInputStream but we don't want
                     *    to wrap a LocalizedInputStream around it.
                     */

                    Class<?> c = i.getClass();
                    while (c != null && 
                           c != java.io.FileInputStream.class &&
                           c != ZipInputStream.class &&
                           c != ZipFileInputStreamClass &&
                           c != FilterInputStream.class) {
                        c = c.getSuperclass();
                    }

                    if (c == FilterInputStream.class) {
                        i= LocalizedInputStream.unwrap((FilterInputStream)i);
                    } else if (c == java.io.FileInputStream.class) {
                        return new LocalizedInputStream(in);
                    } else if (c == ZipFileInputStreamClass) {
                        return new LocalizedInputStream(in);
                    } else {
                        break;
                    }

                }
            }
        }
        return in;
    }

    /**
     * Static method used to extract the input stream inside
     * of the LocalizedInputStream. The method will take any
     * kind of input stream so needs to check that what it is
     * given is actually a LocalizedInputStream. Created to be
     * used by InputStreamReader constructor.
     *
     * @param lis The input stream to "unwrap".
     * @return    If lis is a LocalizedInputStream return the
     *            input stream held inside of it, else
     *            return lis.
     */
    public static InputStream getInputStream(InputStream lis) {

        if (nonASCIIPlatform) {
            if (lis instanceof LocalizedInputStream && 
                ((LocalizedInputStream)lis).allowUnwrapping) {
                return((LocalizedInputStream)lis).in;
            }
        }

        return ConsoleInputStream.getInputStream(lis);
    }

    /**
     * Prevent getInputStream from unwrapping the given
     * LocalizedInputStream.
     *
     * @param fis FilterInputStream from which the input stream 
     *            will be extracted.
     */
    public static void dontUnwrap(InputStream lis) {
        if (nonASCIIPlatform &&
            lis instanceof LocalizedInputStream) {
            ((LocalizedInputStream)lis).allowUnwrapping = false;
        }
    }

    /**
     * Native method used to tunnel into a FilterInputStream
     * and return the input stream it contains.
     *
     * @param fis FilterInputStream from which the input stream 
     *            will be extracted.
     * @return The input stream contained inside of fis.
     */
    public static native InputStream unwrap(FilterInputStream fis);             //IBM-zos_ebcdic

}

//IBM-zos_ebcdic
