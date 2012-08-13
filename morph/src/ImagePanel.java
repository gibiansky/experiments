import javax.swing.*;
import java.awt.event.*;
import java.util.*;
import java.io.*;
import java.awt.*;

public class ImagePanel extends JPanel  {
    private ArrayList<ImageView> imgs = null;

    public ImagePanel(){
        super(true);
        imgs = new ArrayList<ImageView>();
        populate();
    }

    
    public void setImages(ArrayList<ImageView> images){
        imgs = images;
        populate();
    }

    public ArrayList<ImageView> getImageViews(){
        return imgs;
    }

    private void populate(){
        removeAll();

        int numImages = imgs.size();
        int num = numImages + 1;
        int minImg = 7;
        if(numImages < minImg)
            num = 8;
        setLayout(new GridLayout(1, 100));
        int xsize = 125 * num;
        setPreferredSize(new Dimension(xsize, 10));
        setSize(getPreferredSize());

        // add images
        int i;
        for(i = 0; i < numImages; i++){
            JPanel p = imgs.get(i).getMini(100, 90, 7, this);
            add(p);
        }

        // compensate for lack of images
        for(; i < minImg; i++){
            JPanel p = new JPanel();
            add(p);
        }
        

        JButton newImage = new JButton("Add Image");
        add(newImage);
        newImage.addActionListener(new ActionListener(){
            public void actionPerformed(ActionEvent e){
                addImg();
            }
        });

        invalidate();
        doLayout();
    }

    public void removedImg(ImageView view){
        imgs.remove(view);
        populate();
    }

    public void clickedImg(ImageView view){
        if(imgs.indexOf(view) != imgs.size() - 1) {
            Main.left.removeAll();
            Main.right.removeAll();

            Main.right.add(imgs.get(imgs.indexOf(view) + 1), BorderLayout.CENTER);
            Main.left.add(view, BorderLayout.CENTER);

            Main.right.doLayout();
            Main.left.doLayout();

            Main.right.validate();
            Main.left.validate();

            Main.frame.repaint();
            Main.currentFirstImage = imgs.indexOf(view);
        }
    }

    private void addImg(){
        JFileChooser chooser = new JFileChooser();
        chooser.setMultiSelectionEnabled(true);
        if(chooser.showOpenDialog(Main.frame) != JFileChooser.APPROVE_OPTION)
            return;
        File[] imgFiles = chooser.getSelectedFiles();
        for(File imgFile : imgFiles)
            addImgFilename(imgFile.getAbsolutePath());
    }

    private void addImgFilename(String fname){
        Image img = Toolkit.getDefaultToolkit().createImage(fname);

        /* Check that width and height are the same as previous image */
        if(imgs.size() != 0){
            int width, height;
            while(img.getWidth(this) == -1);
            width = img.getWidth(this);

            while(img.getHeight(this) == -1);
            height = img.getHeight(this);

            int widthPrev, heightPrev;
            Image imgPrev = imgs.get(imgs.size() - 1).image;

            while(imgPrev.getWidth(this) == -1);
            widthPrev = imgPrev.getWidth(this);

            while(imgPrev.getHeight(this) == -1);
            heightPrev = imgPrev.getHeight(this);

            if(width != widthPrev || height != heightPrev) {
                JOptionPane.showMessageDialog(Main.frame, "New image is of a different size than previous image.", "Invalid Image Size", JOptionPane.ERROR_MESSAGE);
                return;
            }
        }

        ImageView view = new ImageView(img, fname);
        imgs.add(view);
        populate();
    }
}
