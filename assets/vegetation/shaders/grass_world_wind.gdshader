// World mesh stores each card once. Render both sides instead of duplicating it.
shader_type spatial;
#define GRASS_GUST_DEMO
#define GRASS_SINGLE_SIDED_GEOMETRY
#include "res://assets/vegetation/shaders/vegetation_wind_common.gdshaderinc"
