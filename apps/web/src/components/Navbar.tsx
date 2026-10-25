'use client';

import Link from 'next/link';
import Image from 'next/image';
import { useState } from 'react';
import { APP_CONFIG } from '@/lib/config';
import {
  MapPin,
  QrCode,
  Store,
  ChevronDown,
  LogIn,
  Menu,
  X,
  Compass,
  HelpCircle,
  Info,
  PhoneCall,
} from 'lucide-react';

export default function Navbar() {
  const [selectedCity, setSelectedCity] = useState(APP_CONFIG.defaultCity);
  const [isCityOpen, setIsCityOpen] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const closeMobileMenu = () => setIsMobileMenuOpen(false);

  return (
    <header className="sticky top-0 z-50 bg-[#FDFBF7] border-b border-amber-200/70">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Brand Logo & City Picker */}
          <div className="flex items-center space-x-4 sm:space-x-6">
            <Link
              href="/"
              className="flex items-center space-x-3 group focus:outline-none"
              aria-label={`${APP_CONFIG.brandName} Home`}
              onClick={closeMobileMenu}
            >
              <Image
                src="/brand/logo.png"
                alt={`${APP_CONFIG.brandName} - ${APP_CONFIG.tagline}`}
                width={96}
                height={36}
                className="h-9 w-auto object-contain rounded-md border border-amber-200/60"
              />
              <div className="flex flex-col">
                <span className="font-extrabold text-lg sm:text-xl tracking-tight text-slate-900 group-hover:text-amber-700 transition-colors">
                  {APP_CONFIG.brandName}
                </span>
                <span className="hidden sm:inline-block text-[10px] font-semibold text-amber-800 -mt-1 tracking-tight">
                  {APP_CONFIG.tagline}
                </span>
              </div>
            </Link>

            {/* Location filters appear only after real provider location data is available. */}
            {APP_CONFIG.cities.length > 0 && <div className="relative hidden md:block">
              <button
                type="button"
                onClick={() => setIsCityOpen(!isCityOpen)}
                className="flex items-center space-x-1.5 text-xs font-semibold text-slate-700 bg-amber-50/80 hover:bg-amber-100 px-3 py-1.5 rounded-lg border border-amber-200 transition-colors"
                aria-haspopup="true"
                aria-expanded={isCityOpen}
              >
                <MapPin className="w-3.5 h-3.5 text-amber-700 shrink-0" />
                <span>{selectedCity}</span>
                <ChevronDown className="w-3 h-3 text-slate-500" />
              </button>

              {isCityOpen && (
                <div className="absolute left-0 mt-1.5 w-44 bg-white border border-slate-200 rounded-lg shadow-md py-1 z-50">
                  {APP_CONFIG.cities.map((city) => (
                    <button
                      key={city}
                      type="button"
                      onClick={() => {
                        setSelectedCity(city);
                        setIsCityOpen(false);
                      }}
                      className={`w-full text-left px-3.5 py-1.5 text-xs font-medium transition-colors ${
                        selectedCity === city
                          ? 'bg-amber-50 text-amber-800 font-semibold'
                          : 'text-slate-700 hover:bg-slate-50 hover:text-slate-900'
                      }`}
                    >
                      {city}
                    </button>
                  ))}
                </div>
              )}
            </div>}
          </div>

          {/* Desktop Navigation Links */}
          <nav className="hidden lg:flex items-center space-x-2">
            <Link
              href="/"
              className="text-xs font-semibold text-slate-700 hover:text-amber-800 px-2.5 py-1.5 rounded-lg hover:bg-amber-50 transition-colors"
            >
              Explore
            </Link>
            <Link
              href="/about"
              className="text-xs font-semibold text-slate-700 hover:text-amber-800 px-2.5 py-1.5 rounded-lg hover:bg-amber-50 transition-colors"
            >
              About
            </Link>
            <Link
              href="/faq"
              className="text-xs font-semibold text-slate-700 hover:text-amber-800 px-2.5 py-1.5 rounded-lg hover:bg-amber-50 transition-colors"
            >
              FAQ
            </Link>
            <Link
              href="/contact"
              className="text-xs font-semibold text-slate-700 hover:text-amber-800 px-2.5 py-1.5 rounded-lg hover:bg-amber-50 transition-colors"
            >
              Support
            </Link>

            <span className="h-4 w-px bg-slate-200 mx-1" aria-hidden="true" />

            {/* Customer Pass */}
            <Link
              href="/customer/dashboard"
              className="flex items-center space-x-1.5 text-xs font-semibold text-slate-700 hover:text-slate-900 px-2.5 py-1.5 rounded-lg hover:bg-amber-50 border border-transparent hover:border-amber-200 transition-colors"
            >
              <QrCode className="w-4 h-4 text-emerald-700" />
              <span>Meal Pass</span>
            </Link>

            {/* Provider Portal */}
            <Link
              href="/provider/portal"
              className="flex items-center space-x-1.5 text-xs font-semibold text-slate-700 hover:text-slate-900 px-2.5 py-1.5 rounded-lg hover:bg-amber-50 border border-transparent hover:border-amber-200 transition-colors"
            >
              <Store className="w-4 h-4 text-amber-700" />
              <span>Kitchen Hub</span>
            </Link>

            {/* Sign In */}
            <Link
              href="/auth/login"
              className="flex items-center space-x-1.5 text-xs font-semibold text-white bg-slate-900 hover:bg-slate-800 px-3.5 py-1.5 rounded-lg transition-colors shadow-xs ml-1"
            >
              <LogIn className="w-3.5 h-3.5" />
              <span>Sign In</span>
            </Link>
          </nav>

          {/* Mobile Right Controls: Meal Pass quick button + Hamburger button */}
          <div className="flex items-center space-x-2 lg:hidden">
            <Link
              href="/customer/dashboard"
              className="flex items-center space-x-1 text-xs font-bold text-slate-900 bg-amber-100 border border-amber-300 px-2.5 py-1.5 rounded-lg"
              onClick={closeMobileMenu}
            >
              <QrCode className="w-3.5 h-3.5 text-emerald-700" />
              <span>Pass</span>
            </Link>

            <button
              type="button"
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="p-2 rounded-lg text-slate-700 hover:text-slate-900 hover:bg-amber-100/70 border border-slate-200 transition-colors"
              aria-label="Toggle mobile menu"
              aria-expanded={isMobileMenuOpen}
            >
              {isMobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Drawer Menu */}
      {isMobileMenuOpen && (
        <div className="lg:hidden border-t border-amber-200 bg-[#FDFBF7] px-4 pt-3 pb-6 space-y-4 shadow-lg animate-in fade-in duration-150">
          {/* Location filters appear only after real provider location data is available. */}
          {APP_CONFIG.cities.length > 0 && <div className="flex items-center justify-between pb-2 border-b border-amber-100">
            <span className="text-xs font-semibold text-slate-500 flex items-center space-x-1">
              <MapPin className="w-3.5 h-3.5 text-amber-700" />
              <span>City:</span>
            </span>
            <div className="flex flex-wrap gap-1.5">
              {APP_CONFIG.cities.map((city) => (
                <button
                  key={city}
                  type="button"
                  onClick={() => setSelectedCity(city)}
                  className={`text-xs px-2.5 py-1 rounded-md font-semibold transition-colors ${
                    selectedCity === city
                      ? 'bg-amber-600 text-white'
                      : 'bg-white border border-slate-200 text-slate-700'
                  }`}
                >
                  {city}
                </button>
              ))}
            </div>
          </div>}

          {/* Primary Navigation Links */}
          <div className="grid grid-cols-2 gap-2 text-xs font-semibold">
            <Link
              href="/"
              onClick={closeMobileMenu}
              className="flex items-center space-x-2 p-2.5 rounded-lg bg-white border border-slate-200 text-slate-800 hover:bg-amber-50"
            >
              <Compass className="w-4 h-4 text-amber-700" />
              <span>Explore Messes</span>
            </Link>
            <Link
              href="/customer/dashboard"
              onClick={closeMobileMenu}
              className="flex items-center space-x-2 p-2.5 rounded-lg bg-white border border-slate-200 text-slate-800 hover:bg-amber-50"
            >
              <QrCode className="w-4 h-4 text-emerald-700" />
              <span>My Meal Pass</span>
            </Link>
            <Link
              href="/provider/portal"
              onClick={closeMobileMenu}
              className="flex items-center space-x-2 p-2.5 rounded-lg bg-white border border-slate-200 text-slate-800 hover:bg-amber-50"
            >
              <Store className="w-4 h-4 text-amber-700" />
              <span>Kitchen Partner</span>
            </Link>
            <Link
              href="/contact"
              onClick={closeMobileMenu}
              className="flex items-center space-x-2 p-2.5 rounded-lg bg-white border border-slate-200 text-slate-800 hover:bg-amber-50"
            >
              <PhoneCall className="w-4 h-4 text-slate-700" />
              <span>Contact Support</span>
            </Link>
          </div>

          {/* Secondary Links */}
          <div className="flex items-center justify-around pt-2 border-t border-amber-100 text-xs text-slate-600 font-medium">
            <Link href="/about" onClick={closeMobileMenu} className="hover:text-amber-800">
              About
            </Link>
            <Link href="/faq" onClick={closeMobileMenu} className="hover:text-amber-800">
              FAQ
            </Link>
            <Link href="/terms" onClick={closeMobileMenu} className="hover:text-amber-800">
              Terms
            </Link>
            <Link href="/privacy" onClick={closeMobileMenu} className="hover:text-amber-800">
              Privacy
            </Link>
          </div>

          {/* Sign In Button */}
          <Link
            href="/auth/login"
            onClick={closeMobileMenu}
            className="w-full flex items-center justify-center space-x-2 bg-slate-900 hover:bg-slate-800 text-white font-semibold text-xs py-2.5 rounded-lg transition-colors shadow-xs"
          >
            <LogIn className="w-4 h-4" />
            <span>Sign In to Account</span>
          </Link>
        </div>
      )}
    </header>
  );
}
