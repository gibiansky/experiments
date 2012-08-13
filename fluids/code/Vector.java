/* A two-dimensional vector quantity */
public class Vector {
    /* The zero vector */
    public static final Vector ZERO = new Vector(0, 0);

    /* Vector position */
    double x = 0f, y = 0f;

    /* Create a zero vector */
    public Vector(){
        this(0f, 0f);
    }

    /* Create a vector with a non-zero magnitude */
    public Vector(double px, double py){
        super();
        x = px;
        y = py;
    }

    /* Print the vector in component form */
    public String toString(){
        return "<" + x + ", " + y + ">";
    }
}
