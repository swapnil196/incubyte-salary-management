// Component libraries ship plain CSS that is imported for its side effect.
// TypeScript needs to be told those imports are legal.
declare module "*.css"
