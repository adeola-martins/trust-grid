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

;; REPUTATION SYSTEM
;; Customer review and rating infrastructure
(define-map Reviews
  {
    product-id: uint,
    reviewer: principal,
  }
  {
    rating: uint,
    comment: (string-ascii 200),
    timestamp: uint,
  }
)

;; GLOBAL COUNTERS
(define-data-var product-counter uint u0)

;; BRAND MANAGEMENT FUNCTIONS

;; Register new merchant brand
(define-public (register-brand (name (string-ascii 50)))
  (let ((brand-data {
      name: name,
      verified: false,
      created-at: stacks-block-height,
    }))
    (ok (map-set Brands tx-sender brand-data))
  )
)

;; Platform owner brand verification
(define-public (verify-brand (brand principal))
  (if (is-eq tx-sender contract-owner)
    (let ((brand-data (unwrap! (map-get? Brands brand) (err err-not-brand-owner))))
      (ok (map-set Brands brand (merge brand-data { verified: true })))
    )
    (err err-owner-only)
  )
)

;; DIRECT COMMERCE FUNCTIONS

;; Create new product listing
(define-public (list-product
    (name (string-ascii 100))
    (description (string-ascii 500))
    (price uint)
  )
  (let (
      (brand (unwrap! (map-get? Brands tx-sender) (err err-not-brand-owner)))
      (product-id (+ (var-get product-counter) u1))
    )
    (if (> price u0)
      (begin
        (var-set product-counter product-id)
        (ok (map-set Products product-id {
          brand: tx-sender,
          name: name,
          description: description,
          price: price,
          available: true,
          created-at: stacks-block-height,
          is-auction: false,
        }))
      )
      (err err-invalid-price)
    )
  )
)

;; Execute instant product purchase
(define-public (purchase-product (product-id uint))
  (let (
      (product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
      (price (get price product))
      (brand (get brand product))
      (fee (/ (* price (var-get platform-fee)) u1000))
    )
    (if (and
        (get available product)
        (not (get is-auction product))
        (>= (stx-get-balance tx-sender) price)
      )
      (begin
        (try! (stx-transfer? fee tx-sender contract-owner))
        (try! (stx-transfer? (- price fee) tx-sender brand))
        (map-set Products product-id (merge product { available: false }))
        (ok true)
      )
      (err err-insufficient-funds)
    )
  )
)

;; AUCTION SYSTEM FUNCTIONS

;; Initialize time-bound auction
(define-public (create-auction
    (name (string-ascii 100))
    (description (string-ascii 500))
    (min-price uint)
    (duration uint)
  )
  (let (
      (brand (unwrap! (map-get? Brands tx-sender) (err err-not-brand-owner)))
      (product-id (+ (var-get product-counter) u1))
      (end-block (+ stacks-block-height duration))
    )
    (asserts! (>= duration u10) (err err-invalid-duration))
    (asserts! (> min-price u0) (err err-invalid-price))
    (begin
      (var-set product-counter product-id)
      (try! (map-set Products product-id {
        brand: tx-sender,
        name: name,
        description: description,
        price: min-price,
        available: true,
        created-at: stacks-block-height,
        is-auction: true,
      }))
      (ok (map-set Auctions product-id {
        end-block: end-block,
        min-price: min-price,
        highest-bid: u0,
        highest-bidder: none,
        is-active: true,
      }))
    )
  )
)