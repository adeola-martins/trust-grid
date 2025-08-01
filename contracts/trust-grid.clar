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
(define-constant err-product-unavailable (err u110))
(define-constant err-invalid-input (err u111))
(define-constant err-invalid-brand (err u112))

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

;; INPUT VALIDATION HELPERS

;; Validate string input is not empty
(define-private (is-valid-string (input (string-ascii 500)))
  (> (len input) u0)
)

;; Validate principal is not contract itself
(define-private (is-valid-principal (input principal))
  (not (is-eq input (as-contract tx-sender)))
)

;; Validate product name
(define-private (is-valid-product-name (name (string-ascii 100)))
  (and (> (len name) u0) (<= (len name) u100))
)

;; Validate product description
(define-private (is-valid-description (desc (string-ascii 500)))
  (and (> (len desc) u0) (<= (len desc) u500))
)

;; Validate review comment
(define-private (is-valid-comment (comment (string-ascii 200)))
  (and (> (len comment) u0) (<= (len comment) u200))
)

;; GLOBAL COUNTERS
(define-data-var product-counter uint u0)

;; BRAND MANAGEMENT FUNCTIONS

;; Register new merchant brand
(define-public (register-brand (name (string-ascii 50)))
  (begin
    (asserts! (is-valid-string name) err-invalid-input)
    (let ((brand-data {
        name: name,
        verified: false,
        created-at: stacks-block-height,
      }))
      (ok (map-set Brands tx-sender brand-data))
    )
  )
)

;; Platform owner brand verification
(define-public (verify-brand (brand principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-valid-principal brand) err-invalid-brand)
    (let ((brand-data (unwrap! (map-get? Brands brand) err-not-brand-owner)))
      (ok (map-set Brands brand (merge brand-data { verified: true })))
    )
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
      (brand (unwrap! (map-get? Brands tx-sender) err-not-brand-owner))
      (product-id (+ (var-get product-counter) u1))
    )
    (asserts! (is-valid-product-name name) err-invalid-input)
    (asserts! (is-valid-description description) err-invalid-input)
    (asserts! (> price u0) err-invalid-price)
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
)

;; Execute instant product purchase
(define-public (purchase-product (product-id uint))
  (let (
      (product (unwrap! (map-get? Products product-id) err-listing-not-found))
      (price (get price product))
      (brand (get brand product))
      (fee (/ (* price (var-get platform-fee)) u1000))
    )
    (asserts! (get available product) err-product-unavailable)
    (asserts! (not (get is-auction product)) err-product-unavailable)
    (asserts! (>= (stx-get-balance tx-sender) price) err-insufficient-funds)
    (try! (stx-transfer? fee tx-sender contract-owner))
    (try! (stx-transfer? (- price fee) tx-sender brand))
    (map-set Products product-id (merge product { available: false }))
    (ok true)
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
      (brand (unwrap! (map-get? Brands tx-sender) err-not-brand-owner))
      (product-id (+ (var-get product-counter) u1))
      (end-block (+ stacks-block-height duration))
    )
    (asserts! (is-valid-product-name name) err-invalid-input)
    (asserts! (is-valid-description description) err-invalid-input)
    (asserts! (>= duration u10) err-invalid-duration)
    (asserts! (> min-price u0) err-invalid-price)
    (var-set product-counter product-id)
    (map-set Products product-id {
      brand: tx-sender,
      name: name,
      description: description,
      price: min-price,
      available: true,
      created-at: stacks-block-height,
      is-auction: true,
    })
    (ok (map-set Auctions product-id {
      end-block: end-block,
      min-price: min-price,
      highest-bid: u0,
      highest-bidder: none,
      is-active: true,
    }))
  )
)

;; Submit competitive bid
(define-public (place-bid
    (product-id uint)
    (bid-amount uint)
  )
  (let (
      (product (unwrap! (map-get? Products product-id) err-listing-not-found))
      (auction (unwrap! (map-get? Auctions product-id) err-no-active-auction))
    )
    (asserts! (get is-active auction) err-auction-ended)
    (asserts! (<= stacks-block-height (get end-block auction)) err-auction-ended)
    (asserts! (>= bid-amount (get min-price auction)) err-bid-too-low)
    (asserts! (> bid-amount (get highest-bid auction)) err-bid-too-low)
    (asserts! (>= (stx-get-balance tx-sender) bid-amount) err-insufficient-funds)
    ;; Refund previous highest bidder
    (match (get highest-bidder auction)
      prev-bidder (try! (stx-transfer? (get highest-bid auction) contract-owner prev-bidder))
      true
    )
    ;; Process new bid
    (try! (stx-transfer? bid-amount tx-sender contract-owner))
    (ok (map-set Auctions product-id
      (merge auction {
        highest-bid: bid-amount,
        highest-bidder: (some tx-sender),
      })
    ))
  )
)

;; Finalize auction and transfer ownership
(define-public (end-auction (product-id uint))
  (let (
      (product (unwrap! (map-get? Products product-id) err-listing-not-found))
      (auction (unwrap! (map-get? Auctions product-id) err-no-active-auction))
      (brand (get brand product))
    )
    (asserts! (get is-active auction) err-auction-ended)
    (asserts! (>= stacks-block-height (get end-block auction)) err-auction-ended)
    (match (get highest-bidder auction)
      winner (begin
        (let (
            (bid-amount (get highest-bid auction))
            (fee (/ (* bid-amount (var-get platform-fee)) u1000))
          )
          ;; Process final payment
          (try! (stx-transfer? fee contract-owner contract-owner))
          (try! (stx-transfer? (- bid-amount fee) contract-owner brand))
          ;; Update product availability
          (map-set Products product-id (merge product { available: false }))
          ;; Close auction
          (ok (map-set Auctions product-id (merge auction { is-active: false })))
        )
      )
      err-no-active-auction
    )
  )
)

;; REPUTATION & REVIEW SYSTEM

;; Submit product review and rating
(define-public (add-review
    (product-id uint)
    (rating uint)
    (comment (string-ascii 200))
  )
  (let ((product (unwrap! (map-get? Products product-id) err-listing-not-found)))
    (asserts! (<= rating u5) err-invalid-rating)
    (asserts! (> rating u0) err-invalid-rating)
    (asserts! (is-valid-comment comment) err-invalid-input)
    (asserts! (> product-id u0) err-invalid-input)
    (ok (map-set Reviews {
      product-id: product-id,
      reviewer: tx-sender,
    } {
      rating: rating,
      comment: comment,
      timestamp: stacks-block-height,
    }))
  )
)

;; DATA RETRIEVAL FUNCTIONS

(define-read-only (get-product (product-id uint))
  (ok (map-get? Products product-id))
)

(define-read-only (get-brand (brand principal))
  (ok (map-get? Brands brand))
)

(define-read-only (get-review
    (product-id uint)
    (reviewer principal)
  )
  (ok (map-get? Reviews {
    product-id: product-id,
    reviewer: reviewer,
  }))
)

(define-read-only (get-auction (product-id uint))
  (ok (map-get? Auctions product-id))
)