package main

import (
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// นับจำนวน HTTP requests แบ่งตาม method, path, status code
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests handled by the food ordering backend",
		},
		[]string{"method", "path", "status"},
	)

	// วัด latency ของแต่ละ request (ใช้ Histogram เพื่อคำนวณ P95 ได้)
	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)

	// นับจำนวน orders ที่สร้างสำเร็จ (business metric)
	ordersCreatedTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "food_orders_created_total",
			Help: "Total number of food orders successfully created",
		},
	)
)

func prometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.FullPath()
		if path == "" {
			path = "unknown"
		}

		c.Next()

		duration := time.Since(start).Seconds()
		status := strconv.Itoa(c.Writer.Status())

		httpRequestsTotal.WithLabelValues(c.Request.Method, path, status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, path).Observe(duration)
	}
}

func CORSMiddleware() gin.HandlerFunc {
	allowedOrigin := os.Getenv("ALLOWED_ORIGIN")
	if allowedOrigin == "" {
		allowedOrigin = "http://localhost:5173" // dev
	}

	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

var menu = []map[string]interface{}{
	{"id": 1, "name": "Pizza", "price": 120},
	{"id": 2, "name": "Burger", "price": 89},
	{"id": 3, "name": "Salad", "price": 50},
}

func main() {
	r := gin.Default()

	r.Use(CORSMiddleware())
	r.Use(prometheusMiddleware())

	// Health check endpoint
	r.GET("/health", func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, gin.H{"status": "UP"})
	})

	// Metrics endpoint 
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	api := r.Group("/api")
	{
		// ดึงรายการอาหาร
		api.GET("/menu", func(c *gin.Context) {
			c.JSON(http.StatusOK, menu)
		})

		// สร้างออร์เดอร์ 
		api.POST("/order", func(c *gin.Context) {
			ordersCreatedTotal.Inc() // นับ order
			c.JSON(http.StatusCreated, gin.H{
				"order_id": "ORD-12345",
				"status":   "created",
				"message":  "Order placed successfully!",
			})
		})
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	r.Run(":" + port)
}

