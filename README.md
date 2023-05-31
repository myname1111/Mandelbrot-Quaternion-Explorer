Hello this is a custom program i made to explore the quaternion version of the mandelbrot set. As you may or may not now, normally the quaternion extension of the mandelbrot set is rotationally symetric in the X-axis, however if you do a flip in wx-plane then it makes it look more interesting. In code that flip wold look something like this
```glsl
z.yz = -z.zy
```
It is important to note that before this z must be equal to pos, essentially skipping one iteration, and that it does not affect c.
Sorry for all the bugs, I spent most of my time looking for a good "true" representation of the Mandelbrot set in 3D

Images:
![Image 1](/photos/img1.png)
![Image 2](/photos/img2.png)
![Image 3](/photos/img3.png)
![Image 4](/photos/img4.png)
