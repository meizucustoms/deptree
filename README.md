# DepTree
.so libraries dependencies tree generator (to .json file)

## JSON Format
```json
{
    // 32-bit
    "libraries_32": [
        {
            // Library name
            "name": "libexample.so",

            // Library path
            "name": "vendor/lib/libexample.so",

            // What libraries it uses
            "dependencies": [
                "libexample2.so"
            ],

            // Where is it used
            "used_by": [
                "libexample3.so"
            ]
        }
    ],

    // 64-bit
    "libraries_64": [
        {
            // Library name
            "name": "libexample.so",

            // Library path
            "name": "vendor/lib64/libexample.so",

            // What libraries it uses
            "dependencies": [
                "libexample2.so"
            ],

            // Where is it used
            "used_by": [
                "libexample3.so"
            ]
        }
    ],
}
```