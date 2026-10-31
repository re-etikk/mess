import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/api/',
          '/admin/',
          '/customer/',
          '/rider/',
          '/auth/',
          '/provider/portal',
          '/provider/standee',
        ],
      },
    ],
    sitemap: 'https://www.thali.store/sitemap.xml',
  };
}
