# Ruby WEBrick CRUD Business App

A simple **Ruby-based REST API** built using **WEBrick** that demonstrates **CRUD (Create, Read, Update, Delete)** operations for a basic business entity (**Products**).
This project is designed to understand **HTTP servers, RESTful routes, and API design** in Ruby **without using Rails**.

---

## 📌 Features

* Lightweight HTTP server using **WEBrick**
* REST-style CRUD APIs
* JSON request & response handling
* In-memory data storage (no database)
* Clean and easy-to-understand structure
* Ideal for learning Ruby backend fundamentals

---

## 🛠 Tech Stack

* **Language:** Ruby
* **Server:** WEBrick
* **Data Format:** JSON
* **Storage:** In-memory Ruby arrays

---

## 📂 Project Structure

```
ruby-business-app/
│
├── server.rb       # Main WEBrick server
├── README.md       # Project documentation
```

---

##  Getting Started

### Prerequisites

* Ruby **3.x+**
* RubyGems installed
* `webrick` gem installed

---

### Install WEBrick

```bash
gem install webrick
```

---

### Run the Server

```bash
ruby server.rb
```

Server will start at:

```
http://localhost:3000
```

---
### Products API

####  Create Product

**POST** `/products`

```json
{
  "name": "Laptop",
  "price": 75000
}
```

**Response**

```json
{
  "id": 1,
  "name": "Laptop",
  "price": 75000
}
```

---

####  Get All Products

**GET** `/products`

**Response**

```json
[
  {
    "id": 1,
    "name": "Laptop",
    "price": 75000
  }
]
```

---

####  Get Product By ID

**GET** `/product?id=1`

**Response**

```json
{
  "id": 1,
  "name": "Laptop",
  "price": 75000
}
```

---

####  Update Product

**PUT** `/product?id=1`

```json
{
  "price": 72000
}
```

**Response**

```json
{
  "id": 1,
  "name": "Laptop",
  "price": 72000
}
```

---
####  Delete Product

**DELETE** `/product?id=1`

**Response**

```json
{
  "message": "Product deleted"
}
```

---

##  Testing Using curl

### Create Product

```bash
curl -X POST http://localhost:3000/products \
-H "Content-Type: application/json" \
-d "{\"name\":\"Phone\",\"price\":30000}"
```

---

### Get All Products

```bash
curl http://localhost:3000/products
```

---

### Get Product By ID

```bash
curl http://localhost:3000/product?id=1
```

---

### Update Product

```bash
curl -X PUT http://localhost:3000/product?id=1 \
-H "Content-Type: application/json" \
-d "{\"price\":28000}"
```

---

### Delete Product

```bash
curl -X DELETE http://localhost:3000/product?id=1
```




