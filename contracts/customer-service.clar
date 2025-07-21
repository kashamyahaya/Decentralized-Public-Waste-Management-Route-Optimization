;; Customer Service Contract
;; Handles missed pickup complaints and special requests

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-TICKET (err u401))
(define-constant ERR-TICKET-NOT-FOUND (err u402))
(define-constant ERR-INVALID-REQUEST (err u403))
(define-constant ERR-INVALID-RATING (err u404))

;; Data Variables
(define-data-var next-ticket-id uint u1)
(define-data-var next-request-id uint u1)
(define-data-var total-tickets uint u0)
(define-data-var total-requests uint u0)

;; Data Maps
(define-map service-tickets
  { ticket-id: uint }
  {
    customer-address: (string-ascii 100),
    customer-phone: (string-ascii 20),
    customer-email: (string-ascii 50),
    issue-type: (string-ascii 30),
    description: (string-ascii 300),
    priority: uint,
    status: (string-ascii 20),
    created-at: uint,
    assigned-to: (optional principal),
    resolved-at: (optional uint),
    resolution-notes: (string-ascii 300)
  }
)

(define-map special-requests
  { request-id: uint }
  {
    customer-address: (string-ascii 100),
    customer-phone: (string-ascii 20),
    request-type: (string-ascii 50),
    description: (string-ascii 300),
    requested-date: uint,
    scheduled-date: (optional uint),
    status: (string-ascii 20),
    estimated-cost: uint,
    actual-cost: (optional uint),
    assigned-crew: (optional uint),
    completion-notes: (string-ascii 200)
  }
)

(define-map customer-feedback
  { ticket-id: uint }
  {
    satisfaction-rating: uint,
    service-quality: uint,
    response-time-rating: uint,
    comments: (string-ascii 300),
    would-recommend: bool,
    feedback-date: uint
  }
)

(define-map service-metrics
  { date: uint }
  {
    tickets-created: uint,
    tickets-resolved: uint,
    average-resolution-time: uint,
    customer-satisfaction: uint,
    missed-pickups: uint,
    special-requests-completed: uint
  }
)

;; Authorization check
(define-private (is-authorized (caller principal))
  (or (is-eq caller CONTRACT-OWNER)
      (is-eq caller tx-sender)))

;; Create service ticket
(define-public (create-service-ticket
  (customer-address (string-ascii 100))
  (customer-phone (string-ascii 20))
  (customer-email (string-ascii 50))
  (issue-type (string-ascii 30))
  (description (string-ascii 300))
  (priority uint))
  (let ((ticket-id (var-get next-ticket-id)))
    (asserts! (> (len customer-address) u0) ERR-INVALID-TICKET)
    (asserts! (> (len description) u0) ERR-INVALID-TICKET)
    (asserts! (<= priority u5) ERR-INVALID-TICKET)
    (asserts! (>= priority u1) ERR-INVALID-TICKET)

    (map-set service-tickets
      { ticket-id: ticket-id }
      {
        customer-address: customer-address,
        customer-phone: customer-phone,
        customer-email: customer-email,
        issue-type: issue-type,
        description: description,
        priority: priority,
        status: "open",
        created-at: block-height,
        assigned-to: none,
        resolved-at: none,
        resolution-notes: ""
      })

    (var-set next-ticket-id (+ ticket-id u1))
    (var-set total-tickets (+ (var-get total-tickets) u1))
    (ok ticket-id)))

;; Assign ticket to staff
(define-public (assign-ticket
  (ticket-id uint)
  (staff-member principal))
  (let ((ticket-data (unwrap! (map-get? service-tickets { ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set service-tickets
      { ticket-id: ticket-id }
      (merge ticket-data {
        assigned-to: (some staff-member),
        status: "assigned"
      }))
    (ok true)))

;; Resolve service ticket
(define-public (resolve-ticket
  (ticket-id uint)
  (resolution-notes (string-ascii 300)))
  (let ((ticket-data (unwrap! (map-get? service-tickets { ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len resolution-notes) u0) ERR-INVALID-TICKET)

    (map-set service-tickets
      { ticket-id: ticket-id }
      (merge ticket-data {
        status: "resolved",
        resolved-at: (some block-height),
        resolution-notes: resolution-notes
      }))
    (ok true)))

;; Create special request
(define-public (create-special-request
  (customer-address (string-ascii 100))
  (customer-phone (string-ascii 20))
  (request-type (string-ascii 50))
  (description (string-ascii 300))
  (requested-date uint)
  (estimated-cost uint))
  (let ((request-id (var-get next-request-id)))
    (asserts! (> (len customer-address) u0) ERR-INVALID-REQUEST)
    (asserts! (> (len description) u0) ERR-INVALID-REQUEST)
    (asserts! (>= requested-date block-height) ERR-INVALID-REQUEST)

    (map-set special-requests
      { request-id: request-id }
      {
        customer-address: customer-address,
        customer-phone: customer-phone,
        request-type: request-type,
        description: description,
        requested-date: requested-date,
        scheduled-date: none,
        status: "pending",
        estimated-cost: estimated-cost,
        actual-cost: none,
        assigned-crew: none,
        completion-notes: ""
      })

    (var-set next-request-id (+ request-id u1))
    (var-set total-requests (+ (var-get total-requests) u1))
    (ok request-id)))

;; Schedule special request
(define-public (schedule-special-request
  (request-id uint)
  (scheduled-date uint)
  (assigned-crew uint))
  (let ((request-data (unwrap! (map-get? special-requests { request-id: request-id }) ERR-INVALID-REQUEST)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= scheduled-date block-height) ERR-INVALID-REQUEST)

    (map-set special-requests
      { request-id: request-id }
      (merge request-data {
        scheduled-date: (some scheduled-date),
        assigned-crew: (some assigned-crew),
        status: "scheduled"
      }))
    (ok true)))

;; Complete special request
(define-public (complete-special-request
  (request-id uint)
  (actual-cost uint)
  (completion-notes (string-ascii 200)))
  (let ((request-data (unwrap! (map-get? special-requests { request-id: request-id }) ERR-INVALID-REQUEST)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set special-requests
      { request-id: request-id }
      (merge request-data {
        actual-cost: (some actual-cost),
        status: "completed",
        completion-notes: completion-notes
      }))
    (ok true)))

;; Submit customer feedback
(define-public (submit-feedback
  (ticket-id uint)
  (satisfaction-rating uint)
  (service-quality uint)
  (response-time-rating uint)
  (comments (string-ascii 300))
  (would-recommend bool))
  (begin
    (asserts! (is-some (map-get? service-tickets { ticket-id: ticket-id })) ERR-TICKET-NOT-FOUND)
    (asserts! (<= satisfaction-rating u5) ERR-INVALID-RATING)
    (asserts! (>= satisfaction-rating u1) ERR-INVALID-RATING)
    (asserts! (<= service-quality u5) ERR-INVALID-RATING)
    (asserts! (>= service-quality u1) ERR-INVALID-RATING)
    (asserts! (<= response-time-rating u5) ERR-INVALID-RATING)
    (asserts! (>= response-time-rating u1) ERR-INVALID-RATING)

    (map-set customer-feedback
      { ticket-id: ticket-id }
      {
        satisfaction-rating: satisfaction-rating,
        service-quality: service-quality,
        response-time-rating: response-time-rating,
        comments: comments,
        would-recommend: would-recommend,
        feedback-date: block-height
      })
    (ok true)))

;; Update service metrics
(define-public (update-daily-metrics
  (date uint)
  (tickets-created uint)
  (tickets-resolved uint)
  (average-resolution-time uint)
  (customer-satisfaction uint)
  (missed-pickups uint)
  (special-requests-completed uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set service-metrics
      { date: date }
      {
        tickets-created: tickets-created,
        tickets-resolved: tickets-resolved,
        average-resolution-time: average-resolution-time,
        customer-satisfaction: customer-satisfaction,
        missed-pickups: missed-pickups,
        special-requests-completed: special-requests-completed
      })
    (ok true)))

;; Read-only functions
(define-read-only (get-service-ticket (ticket-id uint))
  (map-get? service-tickets { ticket-id: ticket-id }))

(define-read-only (get-special-request (request-id uint))
  (map-get? special-requests { request-id: request-id }))

(define-read-only (get-customer-feedback (ticket-id uint))
  (map-get? customer-feedback { ticket-id: ticket-id }))

(define-read-only (get-service-metrics (date uint))
  (map-get? service-metrics { date: date }))

(define-read-only (get-total-tickets)
  (var-get total-tickets))

(define-read-only (get-total-requests)
  (var-get total-requests))

(define-read-only (get-next-ticket-id)
  (var-get next-ticket-id))

(define-read-only (get-next-request-id)
  (var-get next-request-id))
