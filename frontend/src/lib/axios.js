import axios from "axios";

const axiosInstance = axios.create({
	baseURL: import.meta.env.NODE_ENV === "development" 
		? "http://localhost:5000/api" 
		: import.meta.env.VITE_API_URL || "/api",
	withCredentials: true,
});

export default axiosInstance;