/* Class containing information about a single particle */
public class Particle {
    /* Preferred density of this liquid */
    public static double restDensity = .01f;

    /* Physical properties */
    double mass = 1f, density = 1f;

    /* Position, velocity, acceleration */
    double x = 0f, y = 0f;
    double vx = 0f, vy = 0f;
    double ax = 0f, ay = 0f;
}
