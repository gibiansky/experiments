import java.awt.image.*;
import javax.swing.*;
import java.util.*;
import java.awt.*;

public class Morpher {
    private static JFrame progressFrame;
    private static JProgressBar bar;
    private static JLabel text;

    public static Image[] morph(Image original, Mesh originalMesh, Image target, Mesh targetMesh, final int frames, final String message){
        Image[] animation = new Image[frames];

        SwingUtilities.invokeLater(new Runnable(){
            public void run(){
                progressFrame = new JFrame("Morph Progress");
                progressFrame.setLocationRelativeTo(null);
                progressFrame.setSize(400, 75);
                JPanel panel = new JPanel();
                panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
                bar = new JProgressBar(0, frames);
                panel.add(bar);
                text = new JLabel("Completed 0 out of " + frames + " frames... " + message);
                panel.add(text);
                progressFrame.getContentPane().add(panel);
                progressFrame.setVisible(true); 
            }
        });

        for(int frame = 0; frame < frames; frame++){
            float alpha = frame * 1 / (float)(frames - 1);
            Image image = intermediateMorph(original, originalMesh, target, targetMesh, alpha);
            animation[frame] = image;

            final int frameVar = frame;
        SwingUtilities.invokeLater(new Runnable(){
            public void run(){
                text.setText("Completed " + (frameVar+1) + " out of " + frames + " frames...  " + message);
                bar.setValue(frameVar);
                progressFrame.repaint();
            }
        });
        }
        SwingUtilities.invokeLater(new Runnable(){
            public void run(){
        progressFrame.dispose();
            }
        });

        return animation;
    }

    private static Image intermediateMorph(Image original, Mesh originalMesh, Image target, Mesh targetMesh, float alpha){
        /* Image size */
        int width, height;

        while(original.getWidth(null) == -1);
        width = original.getWidth(null);

        while(original.getHeight(null) == -1);
        height = original.getHeight(null);

        /* Final image */
        int[][] imageData = new int[width][height];

        int[][] pixelsOriginal = getPixels(original);
        int[][] pixelsTarget = getPixels(target);
        int[][] pixelsIntermediate = new int[pixelsTarget.length][pixelsTarget[0].length];

        Polygon[] originalTris = originalMesh.toTriangles();
        Polygon[] targetTris = targetMesh.toTriangles();

        /* Find intermediate triangle */
        Polygon[] intermediateTris = getIntermediateTriangles(originalTris, targetTris, alpha);

        /* For each triangle */
        // for(int i = 0; i < 1; i++){
        for(int i = 0; i < originalTris.length; i++){
            Polygon pOriginal = originalTris[i];
            Polygon pFinal = intermediateTris[i];

            /* Find transform that goes from original to intermediate */
            float[] transformation = calculateTransform(pOriginal, pFinal);

            /* Find inverse transform */
            float[] inverseTransform = calculateInverseTransform(transformation);

            /* For each pixel in the intermediate triangle */
            for(int x = 0; x < width; x++){
                for(int y = 0; y < height; y++){
                    if(pFinal.contains(x, y)){
                        /* Find original location of pixel through the inverse transform */
                        float[] originalLoc = applyTransform(x, y, inverseTransform);

                        /* Find the color of this original pixel */
                        int color = findColorInContinuum(originalLoc, pixelsOriginal);

                        /* Find color of the final pixel */
                        float[] forwardTransform = calculateTransform(pFinal, targetTris[i]);
                        float[] finalLoc = applyTransform(x, y, forwardTransform);
                        int finalColor = findColorInContinuum(finalLoc, pixelsTarget);

                        /* Combine colors */
                        Color cOriginal = decodeColor(color);
                        Color cFinal = decodeColor(finalColor);
                        float colorAlpha = (float)( Math.exp(Math.log(2) * alpha) - 1);
                        int newRed = (int) (cOriginal.getRed() * (1-colorAlpha) + cFinal.getRed() * colorAlpha);
                        int newGreen = (int) (cOriginal.getGreen() * (1-colorAlpha) + cFinal.getGreen() * colorAlpha);
                        int newBlue = (int) (cOriginal.getBlue() * (1-colorAlpha) + cFinal.getBlue() * colorAlpha);
                        int newColor = 0xFF000000 | (newRed << 16) | (newGreen << 8) | newBlue;

                        /* Color pixel */
                        imageData[x][y] = newColor;
                    }
                }
            }
        }

        Image resultImage = makeImage(imageData);
        return resultImage;
    }

    private static void test1(final Polygon[] original, final Image img){
        JFrame frame = new JFrame("test");
        frame.getContentPane().add(new JPanel(){
            public void paint(Graphics g){
                update(g);
            }
            public void update(Graphics g){
                g.drawImage(img, 0, 0, this);
                g.setColor(Color.blue);
                for(Polygon p : original)
                    g.drawPolygon(p);
            }
        });
        frame.setSize(150, 250);
        frame.setVisible(true);
    }
    
    private static float[] applyTransform(float x, float y, float[] transform){
        float a = transform[0];
        float b = transform[1];
        float c = transform[2];
        float d = transform[3];
        float t = transform[4];
        float s = transform[5];

        float p = a * x + b * y + t;
        float q = c * x + d * y + s;
        float[] result = {p, q};
        return result;
    }

    private static int findColorInContinuum(float[] location, int[][] pixels){
        float x = location[0];
        float y = location[1];

        int intX = Math.round(x);
        int intY = Math.round(y);

        if(intX >= pixels.length) intX = pixels.length - 1;
        if(intY >= pixels[0].length) intY = pixels[0].length - 1;
        if(intY < 0) intY = 0;
        if(intX < 0) intX = 0;

        return pixels[intX][intY];
    }

    private static float[] calculateInverseTransform(float[] transformation){
        float a = transformation[0];
        float b = transformation[1];
        float c = transformation[2];
        float d = transformation[3];
        float t = transformation[4];
        float s = transformation[5];

        float determinant = a * d - b * c;

        float ap = d / determinant;
        float bp = -b / determinant;
        float cp = -c / determinant;
        float dp = a / determinant;
        float mt = - (ap*t+bp*s);
        float ms = - (cp*t+dp*s);
        float[] inv = {ap, bp, cp, dp, mt, ms};
        return inv;
    }

    private static float[] calculateTransform(Polygon pOriginal, Polygon pFinal){
        float a = pFinal.xpoints[0];
        float b = pFinal.ypoints[0];
        float c = pFinal.xpoints[1];
        float d = pFinal.ypoints[1];
        float e = pFinal.xpoints[2];
        float f = pFinal.ypoints[2];

        float A = pOriginal.xpoints[0];
        float B = pOriginal.ypoints[0];
        float C = pOriginal.xpoints[1];
        float D = pOriginal.ypoints[1];
        float E = pOriginal.xpoints[2];
        float F = pOriginal.ypoints[2];

        float x = ((B-D)*(e-c) - (a-c)*(F-D)) / ((B-D)*(E-C) - (A-C)*(F-D));
        float y = (a*(E-C) + A*(c-e) - c*E + e*C)/(A*(D-F) + B*(E-C) + C*F - D*E);
        float t = c - x*C - y*D;

        float z = ((B-D)*(f-d) - (b-d)*(F-D)) / ((B-D)*(E-C) - (A-C)*(F-D));
        float w = (b*(E-C) + A*(d-f) - d*E + f*C)/(A*(D-F) + B*(E-C) + C*F - D*E);
        float s = d - z*C - w*D;

        float[] transform = {x, y, z, w, t, s};
        return transform;
    }

    private static Polygon[] getIntermediateTriangles(Polygon[] originalTris, Polygon[] targetTris, float alpha){
        Polygon[] intermediateTris = new Polygon[originalTris.length];
        for(int i = 0; i < originalTris.length; i++){
            Polygon pOriginal = originalTris[i];
            Polygon pTarget = targetTris[i];

            int[] xptsO = pOriginal.xpoints;
            int[] yptsO = pOriginal.ypoints;
            int[] xptsT = pTarget.xpoints;
            int[] yptsT = pTarget.ypoints;

            int[] xptsI = new int[3];
            int[] yptsI = new int[3];
            for(int j = 0; j < 3; j++){
                xptsI[j] = (int) (alpha * xptsT[j] + (1-alpha) * xptsO[j]);
                yptsI[j] = (int) (alpha * yptsT[j] + (1-alpha) * yptsO[j]);
            }

            Polygon intermediatePoly = new Polygon(xptsI, yptsI, 3);
            intermediateTris[i] = intermediatePoly;
        }
        return intermediateTris;
    }

    private static void test(final Image img){
        JFrame frame = new JFrame("test");
        frame.getContentPane().add(new JPanel(){
            public void paint(Graphics g){
                update(g);
            }
            public void update(Graphics g){
                g.drawImage(img, 0, 0, this);
            }
        });
        frame.setSize(150, 250);
        frame.setVisible(true);
    }

    private static int[][] getPixels(Image img){
        int width, height;

        while(img.getWidth(null) == -1);
        width = img.getWidth(null);

        while(img.getHeight(null) == -1);
        height = img.getHeight(null);

        PixelGrabber grabber = new PixelGrabber(img, 0, 0, width, height, true);
        try {
            boolean grabbed = grabber.grabPixels();
            if(!grabbed){
                System.out.println("Failed to grab pixels!");
                System.exit(1);
            }
        }
        catch(Exception e){}

        int[] dataRaw = (int[]) grabber.getPixels();

        int[][] data = new int[width][height];
        for(int i = 0; i < width; i++){
            for(int j = 0; j < height; j++){
                data[i][j] = dataRaw[i + j * width];
            }
        }
        
        return data;
    }

    private static Image makeImage(int[][] data){
        int width = data.length;
        int height = data[0].length;

        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics graphics = image.getGraphics();

        for(int i = 0; i < width; i ++){
            for(int j = 0; j < height; j++){
                graphics.setColor(decodeColor(data[i][j]));
                graphics.drawLine(i, j, i, j);
            }
        }

        return image;
    }

    private static Color decodeColor(int color){
        int alpha = ((color & 0xFF000000) >> 24); 
        int red = ((color & 0x00FF0000) >> 16); 
        int green = ((color & 0x0000FF00) >> 8);
        int blue = ((color & 0x000000FF) >> 0); 

        Color c = new Color(red, green, blue);
        return c;
    }
    
}
