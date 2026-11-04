/** Fixed world orientation, shared by camera and simulation visibility preferences. */
export const WORLD_VIEW_YAW = Math.PI / 4;
export const WORLD_VIEW_FRONT = { x: Math.sin(WORLD_VIEW_YAW), y: Math.cos(WORLD_VIEW_YAW) };
