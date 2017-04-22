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
 * Reason  Date   Origin   Description
 * ------  ----   ------   ---------------------------------------------------- 
 * 052658  160702 pha      Created 
 * 56662.1 031202 stalleyj Always localize so this works on z/OS 
 * 087093  050505 cwhite   Convert console.encoding to default (file.encoding)
 * 093687  050805 cwhite   Correct default console.encoding
 * 100403  200206 cwhite   fix default console.encoding for z/OS
 * ===========================================================================
 * Module Information:
 *      
 * DESCRIPTION: 
 * Wrapper class used on ASCII platforms when the console encoding differs
 * from the machine's default encoding, particularly Windows.
 * ===========================================================================
 */

package com.ibm.jvm.io;

import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.security.AccessController;
import sun.security.action.GetPropertyAction;
import com.ibm.jvm.io.LocalizedInputStream;                                     /*ibm@100403*/

/**
 * ConsoleInputStream is a wrapper class used by JVM classes to record
 * console charater encodings which don't match the system encoding.
 * Mainly used on Windows and z/OS (when JVM is run in ASCII mode).
 */

public final class ConsoleInputStream extends FilterInputStream {

    private static final String encoding;                                       /*ibm@87093*/
                                                                                /*ibm@87093...*/
    private CharsetDecoder btc = null;
    private CharsetEncoder ctb = null;
    /**                                                                         //IBM-console_io
     * Indicates if conversion is required when reading data                    //IBM-console_io
     */                                                                         //IBM-console_io
    private static boolean conversionRequired;                                  //IBM-console_io
                                                                                //IBM-console_io
    private ByteBuffer reservedIn = null;
    private ByteBuffer reservedOut = null;
    private boolean alreadyClosed = false;

    private static String fileEncoding;
    private static String consoleEncoding;
    private static Charset btcInit = null;
    private static Charset ctbInit = null;

    /* Determine the expected console encoding from the defined system properties,
     * and setup convertors to convert from console encoding to default encoding,
     * when they differ.
     */
    static {
        fileEncoding = AccessController.doPrivileged
                                        (new GetPropertyAction("file.encoding"));
        consoleEncoding = AccessController.doPrivileged
                                        (new GetPropertyAction("console.encoding"));
	if (consoleEncoding == null && LocalizedInputStream.nonASCIIPlatform) { /*ibm@100403...*/
            consoleEncoding = AccessController.doPrivileged
				(new GetPropertyAction("ibm.system.encoding"));
        }                                                                       /*...ibm@100403*/
        if (consoleEncoding == null) consoleEncoding = fileEncoding;
        conversionRequired = false;                                             //IBM-console_io
                                                                                //IBM-console_io
        if (!consoleEncoding.equals(fileEncoding)) {
            if ("z/OS".equals(AccessController.doPrivileged(new GetPropertyAction("os.name")))) {
                if (!Charset.isSupported(consoleEncoding)) consoleEncoding = "IBM1047";
                if (!Charset.isSupported(fileEncoding)) fileEncoding = "IBM1047";
            }
            btcInit = Charset.forName(consoleEncoding);
            consoleEncoding = btcInit.name();
            ctbInit = Charset.forName(fileEncoding);
            fileEncoding = ctbInit.name();
            if (!consoleEncoding.equals(fileEncoding))
                conversionRequired = true;                                      //IBM-console_io
        }
        
        encoding = consoleEncoding;
    }
                                                                                /*...ibm@87093*/
    void init() {
        if (conversionRequired) {
            btc = btcInit.newDecoder();
            ctb = ctbInit.newEncoder();
            btc.onMalformedInput(CodingErrorAction.REPLACE)
               .onUnmappableCharacter(CodingErrorAction.REPLACE);
            ctb.onMalformedInput(CodingErrorAction.REPLACE)
               .onUnmappableCharacter(CodingErrorAction.REPLACE);
        }
    }

    /**
     * Make the constructor private so an instance of this class 
     * can't be created directly.
     */
    private ConsoleInputStream(InputStream in) {                                /*ibm@87093*/
        super(in);
    }

    public static void setConversionRequired(boolean value){                    //IBM-console_io
        conversionRequired=value;                                               //IBM-console_io
        if (consoleEncoding.equals(fileEncoding)) conversionRequired = false;
    }                                                                           //IBM-console_io
                                                                                //IBM-console_io
    /**
     * Static method to localise the console input stream
     * Whenever console encoding matches default encoding simply return the passed
     * input stream since the data encoding will already be correct.
     * Otherwise return a ConsoleInputStream so that data read from the console
     * can be converted to default encoding.
     * 
     * Note that when console data is read via an InputStreamReader the reader
     * calls the getEncoding method to determine console encoding (and thus
     * selects the appropriate converter). InputStreamReader also calls
     * getInptuStream to obtain the raw console input stream. This effectively
     * allows it to bypasses the ConsoleInputStream data convertion.
     * 
     * @param in The input stream to be wrapped.
     * @return   The resulting input stream, which may or may not
     *           have been wrapped.
     */
    public static InputStream localize(InputStream in) {
        if (consoleEncoding.equals(fileEncoding)) {
            return in;
        } else {
            ConsoleInputStream cis = new ConsoleInputStream(in);
            cis.init();
            return cis;
        }
    }

    /**
     * Static method used to extract the encoding of the
     * input stream if it is a ConsoleInputStream.
     *
     * @param  is The input stream to get encoding from.
     * @return    Our encoding
     */
    public static String getEncoding(InputStream is) {

        if (is instanceof ConsoleInputStream) {
            return ConsoleInputStream.encoding;
        }

        return null;
    }


    /**
     * Static method used to extract the input stream inside
     * of the ConsoleInputStream. The method will take any
     * kind of input stream so needs to check that "is"
     * is actually a LocalizedInputStream.
     * Used by LocalizedInputStream.getInputStream()
     *
     * @param  is The input stream to "unwrap".
     * @return    If "is" is a ConsoleInputStream return the
     *            input stream held inside of it, else
     *            return "is".
     */
    static InputStream getInputStream(InputStream is) {

        if (is instanceof ConsoleInputStream) {
            return ((ConsoleInputStream)is).in;
        }

        return is;
    }

                                                                                /*ibm@87093...*/
    public int read() throws IOException {
        byte b[] = new byte[1];
        if (read(b) != -1)
            return b[0] & 0xff;
        else
            return -1;
    }

    public int read(byte b[]) throws IOException {
        return read(b, 0, b.length);
    }

    /**
     * Reads an array of bytes from the input stream, returning the array
     * converted from console encoding to default encoding, if conversion       //IBM-console_io
     * is required, else returns the array without doing any conversion.        //IBM-console_io
     */
    public int read(byte b[], int off, int len) throws IOException {
        int count = 0;

        if(conversionRequired){                                                 //IBM-console_io
            if (null != reservedOut) {
                int remaining = reservedOut.remaining() > len ? len : reservedOut.remaining();
                if (reservedOut.remaining() >= len) {
                    System.arraycopy(reservedOut.array(), reservedOut.position(), b, off, len);
                    reservedOut.position(reservedOut.position()+len);
                    if (!reservedOut.hasRemaining()) reservedOut = null;
                    return len;
                } else {
                    System.arraycopy(reservedOut.array(), reservedOut.position(), b, off, reservedOut.remaining());
                    off += remaining;
                    len -= remaining;
                    count = remaining;
                    reservedOut = null;
                }
            }
            if (alreadyClosed) {
                if (count > 0) return count;
                alreadyClosed = false;
                return -1;
            }
            int temp_len = (int)Math.ceil((double)len / ctb.maxBytesPerChar());
            if (temp_len < ctb.maxBytesPerChar()) temp_len = (int)Math.ceil(ctb.maxBytesPerChar());
            int temp_off = 0;
            byte[] temp_b = null;
            if (null != reservedIn) {
                int remaining = reservedIn.remaining();
                temp_len += remaining;
                temp_b = new byte[temp_len];
                System.arraycopy(reservedIn.array(), reservedIn.position(), temp_b, 0, remaining);
                temp_off = remaining;
                temp_len -= remaining;
                reservedIn = null;
            } else {
                temp_b = new byte[temp_len];
            }
            int temp_count = in.read(temp_b, temp_off, temp_len);
            if (temp_count > 0) {
                ByteBuffer bb = ByteBuffer.wrap(temp_b, 0, temp_off+temp_count);
                CharBuffer cb = CharBuffer.allocate(temp_count);
                CoderResult cr = btc.decode(bb, cb, false);
                if (cr.isOverflow()) {
                    while(!cr.isUnderflow()) {
                        CharBuffer temp_cb = CharBuffer.allocate(cb.limit()*2+1);
                        cb.limit(cb.position());
                        cb.position(0);
                        temp_cb.put(cb);
                        cb = temp_cb;
                        cr = btc.decode(bb, cb, false);
                    }
                }
                if (bb.hasRemaining()) {
                    byte[] ba = new byte[bb.remaining()];
                    System.arraycopy(temp_b, bb.position(), ba, 0, bb.remaining());
                    reservedIn = ByteBuffer.wrap(ba);
                }
                if (0 == cb.position()) return 0;
                byte[] ba = new byte[(int)Math.ceil(cb.position()*ctb.maxBytesPerChar())];
                bb = ByteBuffer.wrap(ba);
                cb.limit(cb.position());
                cb.position(0);
                cr = ctb.encode (cb, bb, false);
                if (cr.isOverflow()) {
                    while(!cr.isUnderflow()) {
                        byte[] temp_ba = new byte[bb.limit() * 2 + 1];
                        ByteBuffer temp_bb = ByteBuffer.wrap(temp_ba);
                        bb.limit(bb.position());
                        bb.position(0);
                        temp_bb.put(bb);
                        bb = temp_bb;
                        cr = btc.decode(bb, cb, false);
                    }
                }
                ba = bb.array();
                if (bb.position() > len) {
                    System.arraycopy(ba, 0, b, off, len);
                    int remaining = bb.position() - len;
                    byte[] temp_ba = new byte[remaining];
                    System.arraycopy(ba, len, temp_ba, 0, remaining);
                    reservedOut = ByteBuffer.wrap(temp_ba);
                    count += len;
                } else {
                    System.arraycopy(ba, 0, b, off, bb.position());
                    count += bb.position();
                }
            } else if (temp_count == -1) {
                ByteBuffer bb = null == reservedIn ? ByteBuffer.wrap(new byte[0]) : reservedIn;
                CharBuffer cb  = CharBuffer.allocate(bb.remaining()+1);
                CoderResult cr = btc.decode(bb, cb, true);
                if (cr.isOverflow()) {
                    while(!cr.isUnderflow()) {
                        CharBuffer temp_cb = CharBuffer.allocate(cb.limit()*2+1);
                        cb.limit(cb.position());
                        cb.position(0);
                        temp_cb.put(cb);
                        cb = temp_cb;
                        cr = btc.decode(bb, cb, true);
                    }
                }
                cr = btc.flush(cb);
                if (cr.isOverflow()) {
                    while(!cr.isUnderflow()) {
                        CharBuffer temp_cb = CharBuffer.allocate(cb.limit()*2+1);
                        cb.limit(cb.position());
                        cb.position(0);
                        temp_cb.put(cb);
                        cb = temp_cb;
                        cr = btc.flush(cb);
                    }
                }
                cb.limit(cb.position());
                cb.position(0);
                byte[] ba = new byte[(int)Math.ceil(cb.position()*ctb.maxBytesPerChar())+1];
                bb = ByteBuffer.wrap(ba);
                cr = ctb.encode (cb, bb, true);
                if (cr.isOverflow()) {
                    while(!cr.isUnderflow()) {
                        byte[] temp_ba = new byte[bb.limit() * 2 + 1];
                        ByteBuffer temp_bb = ByteBuffer.wrap(temp_ba);
                        bb.limit(bb.position());
                        bb.position(0);
                        temp_bb.put(bb);
                        bb = temp_bb;
                        cr = ctb.encode(cb, bb, true);
                    }
                }
                cr = ctb.flush(bb);
                if (cr.isOverflow()) {
                    while(!cr.isUnderflow()) {
                        byte[] temp_ba = new byte[bb.limit() * 2 + 1 ];
                        ByteBuffer temp_bb = ByteBuffer.wrap(temp_ba);
                        bb.limit(bb.position());
                        bb.position(0);
                        temp_bb.put(bb);
                        bb = temp_bb;
                        cr = ctb.flush(bb);
                    }
                }
                ba = bb.array();
                if (bb.position() > len) {
                    System.arraycopy(ba, 0, b, off, len);
                    int remaining = bb.position() - len;
                    byte[] temp_ba = new byte[remaining];
                    System.arraycopy(ba, len, temp_ba, 0, remaining);
                    reservedOut = ByteBuffer.wrap(temp_ba);
                    count += len;
                } else {
                    System.arraycopy(ba, 0, b, off, bb.position());
                    count += bb.position();
                }
                if (0 == count) count = -1;
                btc.reset();
                ctb.reset();
                alreadyClosed = -1 != count;
            }                                                                   //IBM-console_io
        } else {
            count = in.read(b, off, len);
        }
        return count;
    }
                                                                                /*...ibm@87093*/
}
