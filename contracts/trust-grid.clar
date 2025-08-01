;; Title: TrustGrid - Next-Generation Decentralized Commerce Platform
;;
;; Summary:
;; A revolutionary peer-to-peer commerce ecosystem that eliminates traditional
;; e-commerce intermediaries by leveraging Bitcoin's security and Stacks' smart
;; contract capabilities to create a truly trustless marketplace experience.
;;
;; Description:
;; TrustGrid transforms digital commerce by empowering merchants and consumers
;; to transact directly without relying on centralized platforms. The protocol
;; features intelligent escrow mechanisms, dynamic auction systems, reputation
;; scoring, and transparent fee structures. Built with modular architecture,
;; it supports everything from instant purchases to time-bound auctions while
;; maintaining complete transaction transparency and user sovereignty over their
;; commercial activities.
;;

;; ERROR CONSTANTS
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-brand-owner (err u101))
(define-constant err-invalid-price (err u102))
(define-constant err-listing-not-found (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-auction-ended (err u105))
(define-constant err-bid-too-low (err u106))
(define-constant err-no-active-auction (err u107))
(define-constant err-invalid-duration (err u108))
(define-constant err-invalid-rating (err u109))

;; PLATFORM CONFIGURATION
(define-data-var platform-fee uint u25) ;; 2.5% platform fee

;; BRAND REGISTRY
;; Stores merchant brand information and verification status
(define-map Brands
  principal
  {
    name: (string-ascii 50),
    verified: bool,
    created-at: uint,
  }
)

;; PRODUCT CATALOG
;; Comprehensive product listings with pricing and availability
(define-map Products
  uint
  {
    brand: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    price: uint,
    available: bool,
    created-at: uint,
    is-auction: bool,
  }
)

;; AUCTION MECHANISM
;; Time-bound auction system with automatic bid management
(define-map Auctions
  uint
  {
    end-block: uint,
    min-price: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    is-active: bool,
  }
)