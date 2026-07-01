#!/bin/bash

set -e

echo "Testing health endpoint..."
curl -s http://localhost:3000/api/health

echo ""
echo "Testing dashboard summary..."
curl -s http://localhost:3000/api/dashboard/summary

echo ""
echo "Testing inventory endpoint..."
curl -s http://localhost:3000/api/inventory

echo ""
echo "Testing low-stock endpoint..."
curl -s http://localhost:3000/api/alerts/low-stock

echo ""
echo "Smoke tests completed."
