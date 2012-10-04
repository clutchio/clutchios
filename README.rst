Clutch iOS Client
=================

This is the iOS client library for Clutch.io.


Example
=======

Here's how you might use it for simple A/B testing:

.. sourcecode:: obj-c

    [ClutchAB testWithName:@"signUpBtnColor" A:^{
        // Display green sign-up button
    } B:^{
        // Display blue sign-up button
    }];


Documentation
=============

More documentation can be found at: http://docs.clutch.io/