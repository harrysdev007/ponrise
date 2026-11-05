import{handleUpload}from'../server/upload.mjs';
export default async function handler(req,res){return handleUpload(req,res,process.env.PINATA_JWT);}
