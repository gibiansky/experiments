import java.awt.*;
import java.util.*;

/* The main simulation class */
public class Simulation {
    /* Physical constants */
    private final float gravity = 9.8f;
    private final float viscosity = 10;
    private final float surfaceTension = 1000;

    /* How many particles to create */
    private int particleCount = 300;

    /* Particle array */
    ArrayList<Particle> particles = new ArrayList<Particle>(100);

    /* Create and initialize the simulation */
    public Simulation(){
        super();
        initialize();
    }

    /* Update the simulation */
    public void update(int milliseconds){
        double dt = milliseconds / 1000.0f;

        /* Find accelerations */
        for(Particle p : particles){
            calculateAccleration(p);
        }

        /* Apply accelerations */
        for(Particle p : particles){
            p.vx += p.ax * dt;
            p.vy += p.ay * dt;

            /* Reset accelerations to zero */
            p.ax = 0;
            p.ay = 0;
        }

        /* Apply velocities */
        for(Particle p : particles){
            p.x += p.vx * dt;
            p.y += p.vy * dt;
        }

        /* Check for collisions and reverse velocity vectors if needed */
        for(Particle p : particles){
            applyCollisions(p);
        }
    }

    /* Draw the simulation */
    public void draw(Image img){
        Graphics g = img.getGraphics();

        /* Redraw the background */
        g.setColor(Color.white);
        g.fillRect(0, 0, 1100, 1100);

        /* Draw each particle as a red circle */
        int radius = 15;
        int counter = 50;
        for(Particle p : particles){
            int locX = (int) p.x;
            int locY = Display.SIZE_Y - (int) p.y;

            if(counter == 255) counter = 50;
            g.setColor(new Color(counter, 100, 0));
            counter++;
            g.fillOval(locX - radius, locY - radius, 2 * radius, 2 * radius );
        }

        /* Draw the container boundaries in black */
        g.setColor(Color.black);
        g.fillRect(0, 0, 50, Display.SIZE_Y);
        g.fillRect(0, Display.SIZE_Y - 50, Display.SIZE_X, 50);
        g.fillRect(Display.SIZE_X - 50, 0, 50, Display.SIZE_Y);
    }

    /* Initialize particles */
    private void initialize(){
        /* Create all the particles, place them in a rectangle */
        int width = 20;
        int height = particleCount / width;
        int topLeftX = 100, topLeftY = 100;
        int incrementX = 10, incrementY = 10;
        for(int i = 0; i < height; i++){
            for(int j = 0; j < width; j++){
                Particle p = new Particle();
                p.x = topLeftX + incrementX * j;
                p.y = topLeftY + incrementY * i;
                particles.add(p);
            }
        }

        /* Initial pressure */
        precalculateDensities();
        double max = -10000;
        for(Particle p : particles){
            if(p.density > max)
                max = p.density;
        }
        Particle.restDensity = max;
    }

    private void calculateAccleration(Particle p){
        /* Calculate things which are needed to calculate force */
        precalculateDensities();

        /* Calculate individual force terms */
        Vector forcePressure = calculatePressure(p);
        Vector forceViscosity = calculateViscosity(p);
        Vector forceExternal = calculateExternal(p);
        Vector forceSurface = calculateSurfaceTension(p);

        double totalForceX = forcePressure.x + forceViscosity.x + forceExternal.x + forceSurface.x;
        double totalForceY = forcePressure.y + forceViscosity.y + forceExternal.y + forceSurface.y;

        double accelerationX = totalForceX / p.density;
        double accelerationY = totalForceY / p.density;

        /* Apply accelerations */
        p.ax = accelerationX;
        p.ay = accelerationY;
    }

    /* Calculate density of each particle */
    private void precalculateDensities(){
        for(Particle p : particles){
            double sum = 0;
            for(Particle q : particles){
                double product = 1;
                product *= q.mass;
                product *= SmoothingKernels.general(p.x - q.x, p.y - q.y);
                sum += product;
            }

            p.density = sum;
        }
    }

    /* Calculate pressure of given particle */
    private Vector calculatePressure(Particle p){
        double sumX = 0;
        double sumY = 0;
        double constant = 100000;
        double pressure1 = constant * (p.density - Particle.restDensity);
        for(Particle q : particles){
            /* Don't count our own particle because that will lead to a 0 vector and NaN problems */
            if(p != q){
                double pressure2 = constant * (q.density - Particle.restDensity);

                double product = 1;
                product *= q.mass;
                product *= pressure1 + pressure2;
                product *= .5 * q.density;


                /* Account for direction of pressure! */
                if(SmoothingKernels.nonZero(p.x - q.x, p.y - q.y)){
                    Vector factor = SmoothingKernels.pressureGrad(p.x - q.x, p.y - q.y);

                    double dist = Math.sqrt(Math.pow(p.x - q.x, 2) + Math.pow(p.y - q.y, 2));
                    double fromQx = (p.x - q.x)/dist;
                    double fromQy = (p.y - q.y)/dist;

                    /* Calculate directional derivative */
                    double directional = factor.x * fromQx + factor.y * fromQy;

                    sumX += product * directional;
                    sumY += product * directional;
                }
            }

        }

        Vector pressure = new Vector(-sumX, -sumY);
        return pressure;
    }

    /* Calculate viscosity force of given particle */
    private Vector calculateViscosity(Particle p){
        double sumX = 0;
        double sumY = 0;
        for(Particle q : particles){
            double product = 1;
            product *= q.mass;
            product *= 1/q.density;

            Vector difference = new Vector(q.vx - p.vx, q.vy - p.vy);
            double factor = SmoothingKernels.viscosityLaplace(p.x - q.x, p.y - q.y);
            sumX += product * difference.x * factor;
            sumY += product * difference.y * factor;
        }

        sumX *= viscosity;
        sumY *= viscosity;

        Vector viscosityForce = new Vector(sumX, sumY);
        return viscosityForce;
    }

    /* Calculate external forces on this particle */
    private Vector calculateExternal(Particle p){
        return new Vector(0, -gravity * p.mass);
    }

    /* Calculate surface tension force */
    private Vector calculateSurfaceTension(Particle p){
        double sumX = 0;
        double sumY = 0;

        for(Particle q : particles){
            double product = 1;
            product *= q.mass;
            product *= 1/q.density;

            Vector factor = SmoothingKernels.generalGrad(p.x - q.x, p.y - q.y);
            sumX += product * factor.x;
            sumY += product * factor.y;
        }

        double magN = Math.sqrt(sumX*sumX + sumY*sumY);
        double nThreshold = .25;
        if(magN >= nThreshold){
            /* Calculate laplacian of color */
            double colorLaplacian = 0;
            for(Particle q : particles){
                double product = 1;
                product *= q.mass;
                product *= 1/q.density;

                double factor = SmoothingKernels.generalLaplace(p.x - q.x, p.y - q.y);
                colorLaplacian += product * factor;
            }

            /* Calculate surface tension force */
            double surfaceForce = 1;
            surfaceForce *= - surfaceTension;
            surfaceForce *= colorLaplacian;
            surfaceForce /= magN;
            return new Vector(surfaceForce * sumX, surfaceForce * sumY);
        } else {
            return Vector.ZERO;
        }
    }

    /* Reverse direction at collisions */
    private void applyCollisions(Particle p){
        final double dampingFactor = .8;
        if(p.y <= 40){
            p.y = 40;
            p.vy = -p.vy * dampingFactor;
        }
        if(p.x < 50){
            p.x = 50;
            p.vx = -p.vx * dampingFactor;
        }
        if(p.x > 350){
            p.x = 350;
            p.vx = -p.vx * dampingFactor;
        }
    }
}
