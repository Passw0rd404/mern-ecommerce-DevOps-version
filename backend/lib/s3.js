import { S3Client, PutObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import sharp from "sharp";
import crypto from "crypto";
import dotenv from "dotenv";

dotenv.config();

const s3Client = new S3Client({ 
  region: process.env.AWS_REGION || 'eu-north-1'
});

export const uploadToS3 = async (base64Image) => {
  const buffer = Buffer.from(base64Image.replace(/^data:image\/\w+;base64,/, ""), 'base64');
  
  const optimized = await sharp(buffer)
    .resize(1000, 1000, { fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 80 })
    .toBuffer();

  const fileName = `products/${crypto.randomUUID()}.jpg`;
  
  await s3Client.send(new PutObjectCommand({
    Bucket: process.env.S3_BUCKET_NAME,
    Key: fileName,
    Body: optimized,
    ContentType: 'image/jpeg',
  }));

  return process.env.CLOUDFRONT_URL 
    ? `${process.env.CLOUDFRONT_URL}/${fileName}`
    : `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${fileName}`;
};

export const deleteFromS3 = async (imageUrl) => {
  try {
    const url = new URL(imageUrl);
    const key = url.pathname.substring(1);
    
    await s3Client.send(new DeleteObjectCommand({
      Bucket: process.env.S3_BUCKET_NAME,
      Key: key,
    }));
  } catch (error) {
    console.error("S3 Delete Error:", error);
  }
};

export default { uploadToS3, deleteFromS3 };