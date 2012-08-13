import javax.swing.*;
import java.io.*;
import java.util.*;
import java.awt.event.*;
import java.awt.*;

public class Main {
    static JFrame frame;
    static JPanel left;
    static JPanel right;
    static ImagePanel imagePane;
    static int XMESH = 10, YMESH = 10;
    static int currentFirstImage = -1;

    public static void main(String[] args){
        open(null);
    }

    public static void open(final ImagePanel panelOrNull){
        JFrame.setDefaultLookAndFeelDecorated(true);
        SwingUtilities.invokeLater(new Runnable() {
            public void run() {
                try {
                    UIManager.setLookAndFeel("org.pushingpixels.substance.api.skin.SubstanceChallengerDeepLookAndFeel");
                } catch (Exception e) {
                    e.printStackTrace();
                }

                frame = new JFrame("Image Morphing");

                JPanel top = new JPanel();

                JPanel leftView = new JPanel();
                leftView.setLayout(new BorderLayout());
                left = new JPanel();
                left.setLayout(new BorderLayout());
                JLabel ltxt = new JLabel("Source Image");
                leftView.add(left, BorderLayout.CENTER);
                leftView.add(ltxt, BorderLayout.SOUTH);

                JPanel rightView = new JPanel();
                rightView.setLayout(new BorderLayout());
                JLabel rtxt = new JLabel("Destination Image");
                right = new JPanel(); 
                right.setLayout(new BorderLayout());
                rightView.add(right, BorderLayout.CENTER);
                rightView.add(rtxt, BorderLayout.SOUTH);

                top.setLayout(new GridLayout(1, 2));
                top.add(leftView);
                top.add(rightView);

                frame.getContentPane().setLayout(
                        new BoxLayout(frame.getContentPane(), BoxLayout.Y_AXIS));

                if(panelOrNull == null)
                    imagePane = new ImagePanel();
                else
                    imagePane = panelOrNull;
                JScrollPane scrollPane = new JScrollPane(imagePane, 
                        JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
                        JScrollPane.HORIZONTAL_SCROLLBAR_ALWAYS);

                JPanel buttonPanel = new JPanel();

                JButton saveProject = new JButton("Save Project");
                saveProject.addActionListener(new ActionListener(){
                    public void actionPerformed(ActionEvent e){
                        saveProject();
                    }
                });
                JButton loadProject = new JButton("Load Project");
                loadProject.addActionListener(new ActionListener(){
                    public void actionPerformed(ActionEvent e){
                        loadProject();
                    }
                });

                JLabel pts = new JLabel("Frames per Image: ");
                final JTextField fieldFrames = new JTextField("20", 3);
                JLabel blank = new JLabel("     ");

                JButton save = new JButton("Save Video");
                save.addActionListener(new ActionListener(){
                    public void actionPerformed(ActionEvent e){
                        try {
                            final int frames = Integer.parseInt(fieldFrames.getText());

                            new Thread(){
                                public void run(){
                                    ArrayList<ImageView> views = imagePane.getImageViews();
                                    ArrayList<Image> images = new ArrayList<Image>(frames);

                                    for(int i = 0; i < views.size() - 1; i++){
                                        Image from = views.get(i).image;
                                        Mesh fromMesh = views.get(i).mesh;
                                        Image to = views.get(i+1).image;
                                        Mesh toMesh = views.get(i+1).mesh;
                                        Image[] results = Morpher.morph(from, fromMesh, to, toMesh, frames, "(Image " + (i+1) + " of " + views.size() + ")");
                                        for(Image im : results) {
                                            images.add(im);
                                        }
                                    }

                                    createVideo(images, frames);
                                }
                            }.start();
                        } catch (Exception ex){
                            JOptionPane.showMessageDialog(Main.frame, "The number entered for frames per image is invalid.", "Invalid Number", JOptionPane.ERROR_MESSAGE);
                            return;
                        }
                    }
                });
                JButton morph = new JButton("Morph Pair");
                morph.addActionListener(new ActionListener(){
                    public void actionPerformed(ActionEvent e){
                        try {
                            final int frames = Integer.parseInt(fieldFrames.getText());

                            if(Main.currentFirstImage == -1){
                                JOptionPane.showMessageDialog(Main.frame, "Please select pair before morphing.", "No Pair Selected", JOptionPane.ERROR_MESSAGE);
                                return;
                            }
                            new Thread(){
                                public void run(){
                                    ArrayList<ImageView> views = imagePane.getImageViews();
                                    ArrayList<Image> images = new ArrayList<Image>(frames);

                                    int i = Main.currentFirstImage;
                                    Image from = views.get(i).image;
                                    Mesh fromMesh = views.get(i).mesh;
                                    Image to = views.get(i+1).image;
                                    Mesh toMesh = views.get(i+1).mesh;
                                    Image[] results = Morpher.morph(from, fromMesh, to, toMesh, frames, "");
                                    for(Image im : results)
                                        images.add(im);

                                    displayMorphResults(images);
                                }
                            }.start();
                        } catch (Exception ex){
                            JOptionPane.showMessageDialog(Main.frame, "The number entered for frames per image is invalid.", "Invalid Number", JOptionPane.ERROR_MESSAGE);
                            return;
                        }
                    }
                });

                buttonPanel.add(saveProject);
                buttonPanel.add(loadProject);
                buttonPanel.add(blank);
                buttonPanel.add(pts);
                buttonPanel.add(fieldFrames);
                buttonPanel.add(blank);
                buttonPanel.add(save);
                buttonPanel.add(morph);

                top.setPreferredSize(new Dimension(100, 550));
                scrollPane.setPreferredSize(new Dimension(100, 120));
                buttonPanel.setPreferredSize(new Dimension(100, 50));

                frame.getContentPane().add(top);
                frame.getContentPane().add(scrollPane);
                frame.getContentPane().add(buttonPanel);
                frame.setSize(1024, 756);
                frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
                frame.setVisible(true);
            }
        });
    }

    public static void displayMorphResults(final ArrayList<Image> frames){
        JFrame.setDefaultLookAndFeelDecorated(true);
        SwingUtilities.invokeLater(new Runnable() {
            public void run(){
                try {
                    UIManager.setLookAndFeel("org.pushingpixels.substance.api.skin.SubstanceChallengerDeepLookAndFeel");
                } catch (Exception e) {
                    e.printStackTrace();
                }

                /* Image size */
                int width, height;
                Image first = frames.get(0);

                while(first.getWidth(null) == -1);
        width = first.getWidth(null);

        while(first.getHeight(null) == -1);
        height = first.getHeight(null);

        JFrame display = new JFrame("Morphing");
        JPanel center = new FrameDisplay(frames);
        JLabel label = new JLabel("Right click to advance frames.");
        JLabel label2 = new JLabel("Left click to go back frames.");
        JPanel labels = new JPanel();
        labels.setLayout(new BoxLayout(labels, BoxLayout.Y_AXIS));
        labels.add(label);
        labels.add(label2);
        display.getContentPane().add(center, BorderLayout.CENTER);
        display.getContentPane().add(labels, BorderLayout.SOUTH);
        display.setSize(width + 80, height + 90);
        display.setVisible(true);
            }
        });
    }

    public static void createVideo(final ArrayList<Image> frames, int framesPerImage){
        Image fst = frames.get(0);

        int width, height;
        while(fst.getWidth(null) == -1);
        width = fst.getWidth(null);

        while(fst.getHeight(null) == -1);
        height = fst.getHeight(null);

        int framerate = 20;
        int pause = 10;
        int totalFrames = frames.size() + (frames.size() / framesPerImage + 1) * pause;
        try {
            MJPEGGenerator generator 
                = new MJPEGGenerator(new File("Video.avi"), width, height, framerate, totalFrames); 
            /* Add first pause time */
            for(int i = 0; i < pause; i++)
                generator.addImage(frames.get(0));

            int count = 0;
            for(Image img : frames) {
                generator.addImage(img);
                count++;

                if(count % framesPerImage == 0){
                    for(int i = 0; i < pause; i++)
                        generator.addImage(img);
                }
            }
            generator.finishAVI();
        }
        catch (Exception e) { e.printStackTrace(); }
    }

    private static void saveProject(){
        try {
            JFileChooser chooser = new JFileChooser();
            if(chooser.showOpenDialog(Main.frame) != JFileChooser.APPROVE_OPTION)
                return;
            File outputFile = chooser.getSelectedFile();
            ObjectOutputStream oos = new ObjectOutputStream(new FileOutputStream(outputFile));

            ArrayList<ImageView> images = imagePane.getImageViews();
            oos.writeInt(images.size());
            oos.writeInt(XMESH);
            oos.writeInt(YMESH);
            for(ImageView view : images){
                oos.writeObject(view.path);
                oos.writeObject(view.mesh);
            }

            oos.flush();
            oos.close();
        } catch (Exception e) { e.printStackTrace(); }
    }

    private static void loadProject(){
        try {
            JFileChooser chooser = new JFileChooser();
            if(chooser.showOpenDialog(Main.frame) != JFileChooser.APPROVE_OPTION)
                return;
            File inputFile = chooser.getSelectedFile();

            ObjectInputStream ois = new ObjectInputStream(new FileInputStream(inputFile));

            int numViews = ois.readInt();
            XMESH = ois.readInt();
            YMESH = ois.readInt();
            ArrayList<ImageView> views = new ArrayList<ImageView>(numViews);
            for(int i = 0; i < numViews; i++){
                String fname = (String) ois.readObject();
                Mesh mesh = (Mesh) ois.readObject();
                views.add(new ImageView(Toolkit.getDefaultToolkit().createImage(fname), fname, mesh));
            }
            ImagePanel panel = new ImagePanel();
            panel.setImages(views);

            ois.close();

            frame.dispose();
            open(panel);
        } catch (Exception e) { e.printStackTrace(); }
    }

    private static class FrameDisplay extends JPanel implements MouseListener {
        private ArrayList<Image> images;
        private int frame = 0;
        public FrameDisplay(ArrayList<Image> images){
            super(true);
            this.images = images;
            addMouseListener(this);
        }

        public void paint(Graphics g){ update(g); }
        public void update(Graphics g){
            if(frame >= images.size())
                frame = images.size() - 1;
            if(frame <= 0)
                frame = 0;

            Image currentFrame = images.get(frame);
            g.drawImage(currentFrame, 30, 15, this); 
        }   

        public void mouseClicked(MouseEvent e){
            if(e.getButton() == MouseEvent.BUTTON1)
                frame++;
            if(e.getButton() == MouseEvent.BUTTON3)
                frame--;
            repaint();
        }
        public void mousePressed(MouseEvent e){}
        public void mouseReleased(MouseEvent e){}
        public void mouseEntered(MouseEvent e){}
        public void mouseExited(MouseEvent e){}
    }

}
