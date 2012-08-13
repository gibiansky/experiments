import javax.swing.*;
import java.io.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.image.*;

public class ImageView extends JPanel implements MouseListener, MouseMotionListener {
    public transient Image image = null;
    public Mesh mesh;
    public String path = null;
    private int width, height;
    private int mwidth, mheight;
    private int movingX, movingY;
    private int offsetx, offsety;

    public ImageView(Image img, String pth, Mesh m){
        this(img, pth);
        mesh = m;
    }

    public ImageView(Image img, String absolutePath){
        super();
        path = absolutePath;
        image = img;

        while(img.getWidth(this) == -1);
        width = img.getWidth(this);

        while(img.getHeight(this) == -1);
        height = img.getHeight(this);

        mesh = new Mesh(Main.XMESH, Main.YMESH, width, height);
        mwidth = Main.XMESH;
        mheight = Main.YMESH;

        addMouseMotionListener(this);
        addMouseListener(this);
    }

    public JPanel getMini(final int w, final int h, final int hoffset, ImagePanel imgPanel){
        final Image img = image;
        final Image closeIcon = Toolkit.getDefaultToolkit().createImage("CloseIcon.png");
        JPanel mini = new MiniView(w, h, hoffset, img, closeIcon, imgPanel, this);
        mini.setBackground(Color.red);
        return mini;
    }

    public void drawMesh(Graphics g, int offsetx, int offsety){
        this.offsetx = offsetx;
        this.offsety = offsety;
        g.setColor(new Color(0, 0, 255, 100));
        g.fillRect(offsetx, offsety, width, height);

        for(int i = 0; i < mwidth; i ++){
            for(int j = 0; j < mheight; j++){
                Point p = mesh.points[i][j];

                /* Draw connecting lines */
                g.setColor(Color.red);
                if(j != mheight - 1){
                    Point next = mesh.points[i][j+1];
                    g.drawLine(p.x + offsetx, p.y + offsety, next.x + offsetx, next.y + offsety);
                }
                if(i != mwidth - 1){
                    Point next = mesh.points[i+1][j];
                    g.drawLine(p.x + offsetx, p.y + offsety, next.x + offsetx, next.y + offsety);
                }
                if(j != mheight - 1 && i != mwidth -1){
                    Point next = mesh.points[i+1][j+1];
                    g.drawLine(p.x + offsetx, p.y + offsety, next.x + offsetx, next.y + offsety);
                }

                /* Draw circles */
                int radius = 6;
                g.setColor(Color.black);
                g.fillOval(offsetx - radius + p.x, offsety - radius + p.y, 2 * radius, 2 * radius);

                radius = 3;
                g.setColor(Color.yellow);
                g.fillOval(offsetx - radius + p.x, offsety - radius + p.y, 2 * radius, 2 * radius);

                
            }
        }
    }

    public void update(Graphics g){
        int offsetx = 20, offsety = 20;
        g.drawImage(image, offsetx, offsety, this);
        drawMesh(g, offsetx, offsety);
    }
    public void paint(Graphics g){
        update(g);
    }
    public void paintComponent(Graphics g){
        paint(g);
    }

    public void mousePressed(MouseEvent e){
        int x = e.getX() - offsetx;
        int y = e.getY() - offsety;

        for(int i = 0; i < mwidth; i ++){
            for(int j = 0; j < mheight; j++){
                Point p = mesh.points[i][j];
                int radius = 6;
                if(p.distance(x, y) <= radius){
                    if(i != 0 && i != mwidth-1 && j != 0 && j != mheight -1){
                        movingX = i;
                        movingY = j;
                        return;
                    }
                }
            }
        }
    }
    public void mouseReleased(MouseEvent e){
        movingX = movingY = -1;
    }
    public void mouseDragged(MouseEvent e){
        int x = e.getX() - offsetx;
        int y = e.getY() - offsety;

        if(movingX != -1 && movingY != -1){
            mesh.points[movingX][movingY].x = x;
            mesh.points[movingX][movingY].y = y;
            Main.frame.repaint();
        }
    }

    public void mouseMoved(MouseEvent e){}
    public void mouseClicked(MouseEvent e){}
    public void mouseEntered(MouseEvent e){}
    public void mouseExited(MouseEvent e){}


    private class MiniView extends JPanel implements MouseListener {
        private int w, h, hoffset;
        private Image img, closeIcon;
        private ImagePanel panel;
        private ImageView upper;

        public MiniView(int wp, int hp, int hoffsetp, Image imgp, Image closeIconp, ImagePanel panelp, ImageView upperp){
            super(true);
            addMouseListener(this);

            w = wp;
            h = hp;
            hoffset = hoffsetp;
            img = imgp;
            closeIcon = closeIconp;
            panel = panelp;
            upper = upperp;
        }

        public void mouseClicked(MouseEvent e){
            int x = e.getX();
            int y = e.getY();

            /* Clicked on close? */
            if((x > w - 30 && x < w) && (y > 0 && y < 30)) {
                panel.removedImg(upper);
            } 
            
            /* Clicked elsewhere */
            else {
                panel.clickedImg(upper);
            }
        
        }

        public void mousePressed(MouseEvent e){}
        public void mouseReleased(MouseEvent e){}
        public void mouseEntered(MouseEvent e){}
        public void mouseExited(MouseEvent e){}

        public void update(Graphics g) {
            g.drawImage(img, 0, hoffset, w, h, this);
            g.drawImage(closeIcon, w - 20, 8, 20, 20, this);
        }

        public void paint (Graphics g) {
            update(g);
        }
    }
}
