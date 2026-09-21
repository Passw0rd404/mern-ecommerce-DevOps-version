import "dotenv/config";
import { S3Client, PutObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import sharp from "sharp";
import crypto from "crypto";

const REGION = process.env.AWS_REGION;
const BUCKET = process.env.S3_BUCKET_NAME;
// Public base URL of the site, for example https://dev.abdullahsameh.tech
const CDN_URL = (process.env.CLOUDFRONT_URL || "").replace(/\/+$/, "");

// fail at startup instead of at the first upload
if (!REGION || !BUCKET || !CDN_URL) {
	throw new Error("AWS_REGION, S3_BUCKET_NAME and CLOUDFRONT_URL must be set");
}

// no credentials here on purpose:
// on EC2 the SDK uses the instance IAM role automatically
const s3Client = new S3Client({ region: REGION });

export const uploadToS3 = async (base64Image) => {
	const buffer = Buffer.from(base64Image.replace(/^data:image\/\w+;base64,/, ""), "base64");

	const optimized = await sharp(buffer)
		.resize(1000, 1000, { fit: "inside", withoutEnlargement: true })
		.jpeg({ quality: 80 })
		.toBuffer();

	const fileName = `products/${crypto.randomUUID()}.jpg`;

	await s3Client.send(
		new PutObjectCommand({
			Bucket: BUCKET,
			Key: fileName,
			Body: optimized,
			ContentType: "image/jpeg",
			// names are random UUIDs and never overwritten, so cache for a year
			CacheControl: "public, max-age=31536000, immutable",
		})
	);

	// the bucket is private, so images are only reachable through CloudFront
	return `${CDN_URL}/${fileName}`;
};

export const deleteFromS3 = async (imageUrl) => {
	try {
		const key = decodeURIComponent(new URL(imageUrl).pathname.substring(1));

		// only ever delete product images
		if (!key.startsWith("products/")) return;

		await s3Client.send(
			new DeleteObjectCommand({
				Bucket: BUCKET,
				Key: key,
			})
		);
	} catch (error) {
		console.error("S3 Delete Error:", error);
	}
};

export default { uploadToS3, deleteFromS3 };
