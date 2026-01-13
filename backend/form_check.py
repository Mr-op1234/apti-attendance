"""
Google Form Status Checker

This script checks if a Google Form is currently accepting responses or not
by scraping the form page and looking for specific text indicators.
"""

import os
import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configuration - loaded from .env file with defaults
FORM_URL = os.getenv("FORM_URL", "https://forms.gle/dK7QEXzTw8ZoGKsV6")
FORM_TITLE = os.getenv("FORM_TITLE", "APTITUDE CLASS ATTENDANCE 2027 BATCH")
CLOSED_MESSAGE = "is no longer accepting responses"


def check_form_status(url: str = FORM_URL) -> dict:
    """
    Check if the Google Form is open or closed.
    
    Args:
        url: The Google Form URL to check
        
    Returns:
        dict with keys:
            - 'is_open': bool - True if form is accepting responses, False otherwise
            - 'status': str - 'open', 'closed', or 'error'
            - 'message': str - Descriptive message about the form status
    """
    try:
        # Set headers to mimic a browser request
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
        }
        
        # Make the request
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        # Parse the HTML content
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Get the full page text for analysis
        page_text = soup.get_text()
        
        # Check if the closed message is present
        if CLOSED_MESSAGE in page_text:
            return {
                'is_open': False,
                'status': 'closed',
                'message': f"Form '{FORM_TITLE}' is NOT accepting responses (closed)."
            }
        
        # Check if the form title is present (indicates form loaded successfully)
        if FORM_TITLE in page_text:
            return {
                'is_open': True,
                'status': 'open',
                'message': f"Form '{FORM_TITLE}' is OPEN and accepting responses."
            }
        
        # Form loaded but couldn't determine status
        return {
            'is_open': None,
            'status': 'unknown',
            'message': "Could not determine form status. The form page loaded but expected content was not found."
        }
        
    except requests.exceptions.Timeout:
        return {
            'is_open': None,
            'status': 'error',
            'message': "Request timed out. Please check your internet connection."
        }
    except requests.exceptions.RequestException as e:
        return {
            'is_open': None,
            'status': 'error',
            'message': f"Failed to fetch the form page: {str(e)}"
        }
    except Exception as e:
        return {
            'is_open': None,
            'status': 'error',
            'message': f"An unexpected error occurred: {str(e)}"
        }


def is_form_open(url: str = FORM_URL) -> bool:
    """
    Simple helper function that returns True if form is open, False otherwise.
    
    Args:
        url: The Google Form URL to check
        
    Returns:
        bool: True if form is open and accepting responses, False otherwise
    """
    result = check_form_status(url)
    return result['is_open'] is True


if __name__ == "__main__":
    print("=" * 60)
    print("Google Form Status Checker")
    print("=" * 60)
    print(f"\nChecking form: {FORM_URL}")
    print("-" * 60)
    
    result = check_form_status()
    
    print(f"\nStatus: {result['status'].upper()}")
    print(f"Message: {result['message']}")
    
    if result['is_open'] is True:
        print("\n✅ The form is OPEN - You can submit responses!")
    elif result['is_open'] is False:
        print("\n❌ The form is CLOSED - Not accepting responses.")
    else:
        print("\n⚠️ Could not determine form status.")
    
    print("\n" + "=" * 60)
