import java.awt.*;
import javax.swing.*;
import java.awt.image.*;
import java.util.*;

/* The display used for the fluid simulation */
/* This class opens a frame, starts the simulation, and gives the simulation an image to draw on */
public class Display extends JPanel {
    /* Frame size */
    public static int SIZE_X = 400, SIZE_Y = 400;

    /* Timestep in milliseconds */
    public static int TIMESTEP = 100;

    /* Simulation object */
    private Simulation simulation;

    /* Image on which the simulation can draw */
    private Image image;

    public Display(){
        /* Enable double buffering on this panel */
        super(true);

        /* Open the window */
        JFrame frame = new JFrame("Fluid Simulation");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setSize(SIZE_X, SIZE_Y);
        frame.getContentPane().add(this);
        frame.setVisible(true);

        /* Start the simulation and create the image for it to draw on */
        simulation = new Simulation();
        image = createImage(SIZE_X, SIZE_Y);
    }

    /* Called when the simulation should start */
    public void run(){
        /* Update the simulation, draw it, then wait a bit, and repeat */
        while(true){
            simulation.update(TIMESTEP);
            simulation.draw(image);
            repaint();
            try { Thread.sleep(TIMESTEP / 10); } catch(Exception e) {}
        }
    }

    /* Paint the simulation's image onto the panel */
    public void paintComponent(Graphics g){
        update(g);
    }
    public void update(Graphics g){
        g.drawImage(image, 0, 0, null);
    }
}
