import fetch from "node-fetch";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { refresh_token } = req.body;
  if (!refresh_token) {
    return res.status(400).json({ error: "Missing refresh_token" });
  }

  const { SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET } = process.env;

  const basicAuth = Buffer.from(
    `${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`
  ).toString("base64");

  try {
    const response = await fetch("https://accounts.spotify.com/api/token", {
      method: "POST",
      headers: {
        Authorization: `Basic ${basicAuth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token,
      }),
    });

    const data = await response.json();

    return res.status(200).json({
      access_token: data.access_token,
      expires_in: data.expires_in,
    });
  } catch (error) {
    return res.status(500).json({ error: "Server error", details: error });
  }
}
