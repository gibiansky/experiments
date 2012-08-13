/* The fluid simulation's smoothing kernel's */
public class SmoothingKernels {
    public static double h = 10f;

    /* The general smoothing kernel */
    public static double general(double rx, double ry){
        double normsq = rx*rx + ry*ry;
        if(normsq > h*h) return 0;

        double kernelValue = 315.0 / (64 * Math.PI * Math.pow(h, 9)) * Math.pow(Math.pow(h, 2) - normsq, 3);
        double normalizationScaling = 0.698132 * Math.pow(h, 2);
        return kernelValue * normalizationScaling;
    }
    public static Vector generalGrad(double rx, double ry){
        double normsq = rx*rx + ry*ry;
        if(normsq > h*h) return new Vector();

        double normalizationScaling = 0.698132 * Math.pow(h, 2);
        double r = Math.sqrt(normsq);
        final double pi = Math.PI;
        double x = (-(945*r*Math.pow(normsq-Math.pow(h,2),2))/(32*pi*Math.pow(h,9)));
        double y = (-(945*Math.pow((normsq-Math.pow(h,2)),2)*(-3*normsq+h*h))/(64*pi*Math.pow(h,10)));
        return new Vector(x * normalizationScaling, y * normalizationScaling);
    }
    public static double generalLaplace(double rx, double ry){
        double normsq = rx*rx + ry*ry;
        if(normsq > h*h) return 0;

        double normalizationScaling = 0.698132 * Math.pow(h, 2);
        double laplacian = (945 *(-15 * Math.pow(normsq, 3)+ 23 * normsq * normsq * h * h - 9 * normsq * Math.pow(h, 4)+ Math.pow(h, 6)))/(32*Math.PI*Math.pow(h,11));
        return laplacian;
    }

    /* The smoothing kernel used for pressure calculations */
    public static Vector pressureGrad(double rx, double ry){
        double normsq = rx*rx + ry*ry;
        if(normsq > h*h) return new Vector();

        double r = Math.sqrt(normsq);
        double product = 45 / (Math.PI * Math.pow(h, 6)) * Math.pow(r-h, 2);
        double x = -1;
        double y = (2*r - h)/h;

        double normalizationScaling = Math.PI * Math.pow(h, 2) / 60;
        product *= normalizationScaling;
        return new Vector(product * x, product * y);
    }

    /* The smoothing kernel used for viscosity */
    public static double viscosityLaplace(double rx, double ry){
        double normsq = rx*rx + ry*ry;
        if(normsq > h*h) return 0;

        double r = Math.sqrt(normsq);
        /*
        double sum = 0;
        sum += -3 * r / Math.pow(h, 3);
        sum += 2 / Math.pow(h, 2);
        sum += h * Math.pow(r, -3);
        sum += -2 * Math.pow(r, 3) * Math.pow(h, -5);
        sum += 6*r*r* Math.pow(h, -4);
        */

        double sum = 0;
        sum += 45 / Math.PI / Math.pow(h, 6) * (h - r);

        return sum;
    }

    /* Check whether a smoothing kernel could return a non-zero value */
    public static boolean nonZero(double rx, double ry){
        double normsq = rx*rx + ry*ry;
        if(normsq > h*h) return false;
        return true;
    }

}
