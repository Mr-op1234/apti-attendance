"""
APTI Attendance - Main Entry Point

This module serves as the main entry point for the attendance tracking system.
It checks if the Google Form is open based on time slots.
"""

from datetime import datetime, time, timezone, timedelta
from form_check import check_form_status, FORM_URL, FORM_TITLE

# IST Timezone (UTC+5:30)
IST = timezone(timedelta(hours=5, minutes=30))


# Time Slots Configuration
# Each slot has: id, day (0=Monday, 1=Tuesday, ... 4=Friday), start_time, end_time
TIME_SLOTS = {
    'tue_930': {
        'label': '9:30 - 11:10 AM',
        'day': 'Tuesday',
        'day_number': 1,  # Tuesday
        'start': time(9, 25),   # 5 min buffer before
        'end': time(11, 15),    # 5 min buffer after
    },
    'fri_1110': {
        'label': '11:10 AM - 12:50 PM',
        'day': 'Friday',
        'day_number': 4,  # Friday
        'start': time(11, 5),
        'end': time(12, 55),
    },
    'tue_140': {
        'label': '1:40 - 3:20 PM',
        'day': 'Tuesday',
        'day_number': 1,  # Tuesday
        'start': time(13, 35),
        'end': time(15, 25),
    },
    'tue_1110': {
        'label': '11:10 AM - 12:50 PM',
        'day': 'Tuesday',
        'day_number': 1,  # Tuesday
        'start': time(11, 5),
        'end': time(12, 55),
    },
}


def is_within_time_slot(slot_id: str) -> dict:
    """
    Check if current time is within the specified time slot.
    
    Args:
        slot_id: The time slot identifier
        
    Returns:
        dict with:
            - 'is_active': bool - True if current time is within slot
            - 'slot_info': dict - Information about the slot
            - 'message': str - Description of status
    """
    if slot_id not in TIME_SLOTS:
        return {
            'is_active': False,
            'slot_info': None,
            'message': f"Unknown slot ID: {slot_id}"
        }
    
    slot = TIME_SLOTS[slot_id]
    now = datetime.now(IST)  # Use IST timezone
    current_day = now.weekday()  # Monday=0, Sunday=6
    current_time = now.time()
    
    # Check if correct day
    if current_day != slot['day_number']:
        return {
            'is_active': False,
            'slot_info': slot,
            'message': f"Today is not {slot['day']}. Slot '{slot['label']}' only active on {slot['day']}."
        }
    
    # Check if within time window
    if slot['start'] <= current_time <= slot['end']:
        return {
            'is_active': True,
            'slot_info': slot,
            'message': f"Slot '{slot['label']}' is currently active."
        }
    else:
        return {
            'is_active': False,
            'slot_info': slot,
            'message': f"Current time is outside slot window ({slot['label']})."
        }


def check_form_for_slot(slot_id: str) -> dict:
    """
    Check if the Google Form is open for a specific time slot.
    Only actually checks the form if within the slot's active window.
    
    Args:
        slot_id: The time slot identifier
        
    Returns:
        dict with:
            - 'is_open': bool/None - True if form is open, False if closed, None if not checked
            - 'status': str - 'open', 'closed', 'outside_slot', 'error'
            - 'message': str - Descriptive message
            - 'slot_id': str - The slot ID that was checked
            - 'slot_active': bool - Whether slot is currently active
    """
    # First check if we're within the time slot
    slot_check = is_within_time_slot(slot_id)
    
    if not slot_check['is_active']:
        return {
            'is_open': None,
            'status': 'outside_slot',
            'message': slot_check['message'],
            'slot_id': slot_id,
            'slot_active': False,
            'form_url': FORM_URL,
            'form_title': FORM_TITLE,
        }
    
    # We're within the slot window - actually check the form
    print(f"[MAIN] Slot {slot_id} is active - checking form...")
    form_result = check_form_status()
    
    return {
        'is_open': form_result['is_open'],
        'status': form_result['status'],
        'message': form_result['message'],
        'slot_id': slot_id,
        'slot_active': True,
        'form_url': FORM_URL,
        'form_title': FORM_TITLE,
    }


def main(slot_id: str = None) -> dict:
    """
    Main function that checks the Google Form status for a specific slot.
    
    Args:
        slot_id: The time slot to check. If None, returns slot info only.
    
    Returns:
        dict: Form status information
    """
    if slot_id is None:
        # Return available slots
        return {
            'status': 'info',
            'message': 'No slot specified. Available slots listed.',
            'available_slots': list(TIME_SLOTS.keys()),
            'slots_detail': {k: {'label': v['label'], 'day': v['day']} 
                           for k, v in TIME_SLOTS.items()}
        }
    
    print(f"[MAIN] Checking form status for slot: {slot_id}")
    result = check_form_for_slot(slot_id)
    
    # Log the result
    if result['slot_active']:
        if result['is_open']:
            print(f"[MAIN] ✅ Form is OPEN for slot {slot_id}")
        else:
            print(f"[MAIN] ❌ Form is CLOSED for slot {slot_id}")
    else:
        print(f"[MAIN] ⏸️ Slot {slot_id} not active: {result['message']}")
    
    return result


def get_all_slots() -> dict:
    """
    Get information about all available time slots.
    
    Returns:
        dict: All slot information
    """
    return {
        'slots': TIME_SLOTS,
        'current_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'current_day': datetime.now().strftime('%A'),
    }


if __name__ == "__main__":
    import sys
    
    print("=" * 50)
    print("APTI Attendance - Time Slot Based Checker")
    print("=" * 50)
    
    # Check if slot ID provided as argument
    slot_id = sys.argv[1] if len(sys.argv) > 1 else None
    
    if slot_id:
        result = main(slot_id)
        print(f"\nSlot: {slot_id}")
        print(f"Status: {result['status']}")
        print(f"Message: {result['message']}")
        if result.get('is_open') is not None:
            print(f"Form Open: {result['is_open']}")
    else:
        print("\nAvailable Time Slots:")
        print("-" * 50)
        for slot_id, slot_info in TIME_SLOTS.items():
            print(f"  {slot_id}: {slot_info['label']} ({slot_info['day']})")
        print("\nUsage: python main.py <slot_id>")
        print("Example: python main.py tue_930")
