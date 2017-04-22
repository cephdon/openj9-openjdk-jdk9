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
 * Change activity:
 *
 * Reason  Date   Origin  Description
 * ------  ----   ------  ----------------------------------------------------
 * 009013  030400 hdngmr: NL conversion on System.out & System.err printing.
 * 042032  090302 kwb:    Use console.encoding
 * 061638  010703 cwhite  Fix console.encoding for byte arrays + rename
 * 100403  200206 cwhite  fix default console.encoding for z/OS
 *
 * Description:
 *     Wrapper class to perform NL to line.separator conversion on platforms
 *     where the line.separator != "\n". Intended for use on System.out and
 *     System.err .
 */

package com.ibm.jvm.io;

import java.io.Console;
import java.io.PrintStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;                         //ibm.43032
import java.security.AccessController;
import sun.security.action.GetPropertyAction;
import com.ibm.jvm.io.LocalizedInputStream;                                     /*ibm@100403*/

/**
 * ConsolePrintStream is a wrapper class used by the JVM to do NL conversion
 * on print() or println() calls for char, char[], String or Object parameters
 * (ie.anything which might contain '\n' characters to 'request' line separator
 * sequences be output).
 *
 * Note: the use of '\n' in Strings for this purpose is not encouraged - calls
 * to println() and/or use of the System property "line.separator" should be
 * used instead. However, its use in this way is widespread).
 * The NL coversion will replace any '\n' characters not part of the line
 * separator string (as defined by the System property "line.separator") in the
 * input parameter with the line separator string.
 *
 * This class contains a localize() method, which may be called (passing an
 * OutputStream object and, optionally, an autoFlush boolean for the
 * PrintStream constructor) to obtain a ConsolePrintStream object - if the
 * current "line.separator" property is equal to "\n", a new PrintStream object
 * is returned (as no conversion need take place), otherwise a new
 * ConsolePrintStream object is returned.
 *
 * If the System property console.encoding is set, this encoding will be used
 * for the PrintStream.  This is for use on Windows where the console is often
 * in a different encoding than the ansi codepage.  console.encoding is set by
 * the java command (but not by javaw) and may be set or reset by the user
 * during invocation.
 *
 */
public final class ConsolePrintStream extends PrintStream                       /*ibm@61638*/
{
    /**
     * cache of the System property "line.separator".
     */
    private String lineSeparator;

    /**
     * Index of 1st occurance of '\n' in lineSeparator.
     */
    private int lineSeparatorNLIndex;
                                                                                /*ibm@61638...*/
    /**
     * Indicates if conversion is required when writing bytes
     */
    private static boolean conversionRequired;

    /**
     * Wrapped PrintStream object used for all print and write operations
     */
    private PrintStream ps;
                                                                                /*...ibm@61638*/

    /**
     * Private constuctor with default encoding.  The instance is
     * created by calls to the static localize() method.
     */
    private ConsolePrintStream(OutputStream out, boolean autoFlush,             /*ibm@61638*/
                                 String lineSep,                                //IBM-console_io
                                 boolean conversionRequired) {                  //IBM-console_io
        super(out, autoFlush);
        ps = new PrintStream(out, autoFlush);                                   /*ibm@61638*/
        lineSeparator = lineSep;
        lineSeparatorNLIndex = lineSeparator.indexOf('\n');
        ConsolePrintStream.conversionRequired = conversionRequired;                            //IBM-console_io
    }

    public static void setConversionRequired(boolean value){                    //IBM-zos_ebcdic
	conversionRequired=value;                                               //IBM-zos_ebcdic
    }                                                                           //IBM-zos_ebcdic
    //ibm.43032  begin
    /**
     * Private constuctor with encoding specified.  The instance is
     * created by calls to the static localize() method.
     */
    private ConsolePrintStream(OutputStream out, boolean autoFlush,             /*ibm@61638*/
                                 String lineSep, String encoding,               //IBM-console_io
                                                 boolean conversionRequired)                    //IBM-console_io
            throws UnsupportedEncodingException {
        super(out, autoFlush, encoding);
        ps = new PrintStream(out, autoFlush, encoding);                         /*ibm@61638*/
        lineSeparator = lineSep;
        lineSeparatorNLIndex = lineSeparator.indexOf('\n');
        ConsolePrintStream.conversionRequired = conversionRequired;                           //IBM-console_io
    }
    //ibm.43032  end


                                                                                /*ibm@61638...*/
    /**
     * Write the specified byte to this stream.  If the byte is a newline and
     * automatic flushing is enabled then the <code>flush</code> method will be
     * invoked.
     *
     * <p> Note that the byte is written as given; to write a character that
     * will be translated according to the platform's default character
     * encoding, use the <code>print(char)</code> or <code>println(char)</code>
     * methods. The exception to this is when console.encoding system property
     * is defined in which case the byte stream is converted from default
     * encoding to console.encoding.
     *
     * @param  b  The byte to be written
     * @see #print(char)
     * @see #println(char)
     */
    public void write(int b) {
        if (conversionRequired) {
            ps.print((char)b);
        } else {
            ps.write(b);
        }
    }

    /**
     * Write <code>len</code> bytes from the specified byte array starting at
     * offset <code>off</code> to this stream.  If automatic flushing is
     * enabled then the <code>flush</code> method will be invoked.
     *
     * <p> Note that the bytes will be written as given; to write characters
     * that will be translated according to the platform's default character
     * encoding, use the <code>print(char)</code> or <code>println(char)</code>
     * methods. The exception to this is when console.encoding system property
     * is defined in which case the byte stream is converted from default
     * encoding to console.encoding.
     *
     * @param  buf   A byte array
     * @param  off   Offset from which to start taking bytes
     * @param  len   Number of bytes to write
     */
    public void write(byte buf[], int off, int len) {
        if (conversionRequired) {
            ps.print(new String(buf,off,len)); // String effectively reverse encodes
                                               // the data to UTF-8 and print will
                                               // convert to console.encoding.
                                               // Note: This assumes that buf[] is
                                               // file.encoding encoded.
        } else {
            ps.write(buf,off,len);
        }
    }
    
    /* Ensure that all public methods of PrintStream are overridden  */
    /* so that we can forward onto our local PrintStream             */
    /* This is necessary because our inherited PrintStream methods   */
    /* will indirectly use the above write methods, resulting in     */
    /* mangled text output                                           */
     
    public boolean checkError() {
	    return ps.checkError();
    }

    public void close() {
        ps.close();
    }

    public void flush() {
        ps.flush();
    }

    public void print(boolean b) {
        ps.print(b);
    }
    
    public void print(int i) {
        ps.print(i);
    }

    public void print(long l) {
        ps.print(l);
    }

    public void print(float f) {
        ps.print(f);
    }

    public void print(double d) {
        ps.print(d);
    }

    public void println() {
        ps.println();
    }
    
    public void println(boolean x) {
        ps.println(x);
    }

    public void println(int x) {
        ps.println(x);
    }

    public void println(long x) {
        ps.println(x);
    }

    public void println(float x) {
        ps.println(x);
    }
    
    public void println(double x) {
        ps.println(x);
    }
                                                                                /*...ibm@61638*/

    /**
     * Call our local (PrintStream) print() method, performing NL
     * conversion as we do.
     */
    public void print(char c) {
        if (c != '\n') {
            ps.print(c);                                                        /*ibm@61638*/
        } else {
            ps.print(lineSeparator);                                            /*ibm@61638*/
        }
    }

    /**
     * Call our local (PrintStream) print() method, performing NL
     * conversion as we do.
     */
    public void print(char[] s) {
        ps.print(getNewlinedString(s, false));                                  /*ibm@61638*/
    }

    /**
     * Call our local (PrintStream) print() method, performing NL
     * conversion as we do.
     */
    public void print(String s) {
        ps.print(getNewlinedString(s));                                         /*ibm@61638*/
    }

    /**
     * Call our local (PrintStream) print() method, performing NL
     * conversion as we do.
     */
    public void print(Object obj) {
        ps.print(getNewlinedString(obj));                                       /*ibm@61638*/
    }

    /**
     * Call our local (PrintStream) println() method, performing NL
     * conversion as we do.
     */
    public void println(char c) {
        if (c != '\n') {
            ps.println(c);                                                      /*ibm@61638*/
        } else {
            ps.println(lineSeparator);                                          /*ibm@61638*/
        }
    }

    /**
     * Call our local (PrintStream) println() method, performing NL
     * conversion as we do.
     */
    public void println(char[] s) {
        ps.println(getNewlinedString(s, false));                                /*ibm@61638*/
    }

    /**
     * Call our local (PrintStream) println() method, performing NL
     * conversion as we do.
     */
    public void println(String s) {
        ps.println(getNewlinedString(s));                                       /*ibm@61638*/
    }

    /**
     * Call our local (PrintStream) println() method, performing NL
     * conversion as we do.
     */
    public void println(Object obj) {
        ps.println(getNewlinedString(obj));                                     /*ibm@61638*/
    }

    /**
     * Private method to perform the NL conversion on the String of the object
     * provided.
     * @param obj Object whose string is to be NL converted.
     * @return    Converted string.
     */
    private String getNewlinedString(Object obj) {
        return getNewlinedString(obj, true);
    }

    /**
     * Private method to perform the NL conversion on the String of the object
     * provided.
     * @param obj           Object whose string is to be NL converted.
     * @param treatAsObject If obj is a char[], treat it as an Object when
     *                      obtaining its String.
     * @return              Converted string.
     */
    private String getNewlinedString(Object obj, boolean treatAsObject) {
        if (obj == null) {
            return null;
        }

        String s = ((obj instanceof char[]) && !treatAsObject) ?
            new String((char[])obj) : String.valueOf(obj);

        if(s == null){                                          /*ibm@28207*/
            return null;                                        /*ibm@28207*/
        }                                                       /*ibm@28207*/

        int index = s.indexOf('\n');

        if (index == -1) {
            return s;
        }

        char[] c = ((obj instanceof char[]) && !treatAsObject) ?
            (char[])obj : s.toCharArray();
        StringBuffer buffer = new StringBuffer(c.length);
        int oldIndex = 0;

        while (index != -1) {
            if ((lineSeparatorNLIndex != -1) &&
                (s.regionMatches(index - lineSeparatorNLIndex, lineSeparator,
                                 0, lineSeparator.length()))) {
                index =
                    index + lineSeparator.length() - lineSeparatorNLIndex - 1;
            } else {
                buffer.append(c, oldIndex, index - oldIndex);
                buffer.append(lineSeparator);
                oldIndex = index + 1;
            }
            index = s.indexOf('\n', index + 1);
        }

        if (buffer.length() == 0) {
            return s;
        }

        if (oldIndex < c.length) {
            buffer.append(c, oldIndex, c.length - oldIndex);
        }
        return buffer.toString();
    }

    /**
     * Method to obtain a PrintStream object which will convert '\n' characters
     * (not part of the line separator string) with the line separator string.
     *
     * @param out The output stream to be held in the PrintStream object.
     * @return    The resulting PrintStream object, which may or may not be an
     *            instance of ConsolePrintStream.
     */
    public static PrintStream localize(OutputStream out) {
        return localize(out, false);
    }

    /**
     * Method to obtain a PrintStream object which will convert '\n' characters
     * (not part of the line separator string) with the line separator string.
     *
     * @param out       The output stream to be held in the PrintStream object.
     * @param autoFlush boolean second parameter to be passed to the PrintStream
     *                  constructor.
     * @return          The resulting PrintStream object, which may or may not
     *                  be an instance of ConsolePrintStream.
     */
    public static PrintStream localize(OutputStream out, boolean autoFlush) {
        if (out instanceof ConsolePrintStream) {                                /*ibm@61638*/
            return (PrintStream)out;
        }
        boolean conversionRequired;                                             //IBM-console_io

        String lineSep =
            AccessController.doPrivileged(new GetPropertyAction("line.separator"));
        //ibm.42032  begin
        String encoding =
            AccessController.doPrivileged(new GetPropertyAction("console.encoding"));
	
        if (encoding == null && LocalizedInputStream.nonASCIIPlatform) {        /*ibm@100403...*/
	    encoding = AccessController.doPrivileged
                            (new GetPropertyAction("ibm.system.encoding"));
	}                                                                       /*...ibm@100403*/

        if (encoding!=null && encoding.length()==0)
            encoding = null;
        
        String defaultEncoding =                                                /*ibm@061638...*/
            AccessController.doPrivileged(new GetPropertyAction("file.encoding"));
        if (encoding == null || encoding.equals(defaultEncoding)) {             //IBM-console_io
            conversionRequired = false;
        } else {
            conversionRequired = true;
        }                                                                       /*...ibm@061638*/

        if (lineSep.equals("\n")) {
            if (out instanceof PrintStream) {
                return (PrintStream)out;
            } else {
                if (encoding != null) {
                    try {
                        return (PrintStream)new ConsolePrintStream(out, autoFlush, lineSep, encoding,/*ibm@061638*/ //IBM-console_io
                                                                                            conversionRequired); //IBM-console_io
                    } catch (Exception e) { }
                }
                return new PrintStream(out, autoFlush);
            }
        }

        if (encoding != null) {
            try {
                return (PrintStream)new ConsolePrintStream(out, autoFlush, lineSep, encoding, /*ibm@061638*/ //IBM-console_io
                                                                                    conversionRequired); //IBM-console_io
            } catch (Exception e) { }
        }
        //ibm.42032  end
        return (PrintStream)new ConsolePrintStream(out, autoFlush, lineSep,/*ibm@061638*/ //IBM-console_io
                                                                   conversionRequired); //IBM-console_io
    }
}
//IBM-zos_ebcdic
//IBM-console_io
