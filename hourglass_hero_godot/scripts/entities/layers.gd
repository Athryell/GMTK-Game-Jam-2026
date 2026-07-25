## Named 2D physics layer bits.
##
## These must stay in sync with Project > Settings > Layer Names > 2D Physics.
class_name Layers
extends RefCounted

const SOLID := 1 << 0 ## Anything you can stand on or bump into.
const PLAYER := 1 << 1 ## The hourglass itself — what Area2Ds detect.
