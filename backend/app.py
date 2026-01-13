"""
Hugging Face Spaces Entry Point

This is the entry point for Hugging Face Spaces deployment.
It provides API endpoints for time-slot-based form status checking.
"""

import gradio as gr
from fastapi import FastAPI, Query
from fastapi.responses import JSONResponse
import uvicorn
from datetime import datetime
from main import check_form_for_slot, TIME_SLOTS, FORM_URL, FORM_TITLE, IST


# Global tracking
check_stats = {slot_id: {'checks': 0, 'last_status': None} for slot_id in TIME_SLOTS}


def api_check_slot(slot_id: str) -> dict:
    """
    API endpoint to check form status for a specific slot.
    This is the main API that the Flutter app will call.
    """
    if not slot_id or slot_id not in TIME_SLOTS:
        return {
            'error': True,
            'message': f'Invalid slot_id. Valid options: {list(TIME_SLOTS.keys())}',
            'is_open': None,
            'status': 'error'
        }
    
    result = check_form_for_slot(slot_id)
    
    # Update stats
    check_stats[slot_id]['checks'] += 1
    check_stats[slot_id]['last_status'] = result['status']
    
    return result


def format_slot_status(slot_id: str) -> str:
    """Format slot status for Gradio display."""
    if not slot_id:
        return "Please select a time slot."
    
    result = api_check_slot(slot_id)
    timestamp = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S")
    
    status_emoji = "✅" if result.get('is_open') else "❌" if result.get('is_open') is False else "⏸️"
    
    output = f"""
## Slot Check Result

**Timestamp:** {timestamp}

**Slot:** {slot_id} ({TIME_SLOTS.get(slot_id, {}).get('label', 'Unknown')})

**Day:** {TIME_SLOTS.get(slot_id, {}).get('day', 'Unknown')}

---

### Status: {status_emoji} {result.get('status', 'unknown').upper()}

**Slot Active:** {'Yes' if result.get('slot_active') else 'No'}

**Message:** {result.get('message', 'No message')}

---

**Form URL:** [{FORM_TITLE}]({FORM_URL})
"""
    return output


def get_current_info() -> str:
    """Get current time and active slot information."""
    now = datetime.now(IST)  # Use IST timezone
    current_day = now.strftime('%A')
    current_time = now.strftime('%H:%M:%S')
    
    active_slots = []
    for slot_id, slot_info in TIME_SLOTS.items():
        if now.weekday() == slot_info['day_number']:
            if slot_info['start'] <= now.time() <= slot_info['end']:
                active_slots.append(f"{slot_id} ({slot_info['label']})")
    
    output = f"""
## Current Status

**Date:** {now.strftime('%Y-%m-%d')}

**Day:** {current_day}

**Time:** {current_time}

---

### Active Slots Right Now:
"""
    
    if active_slots:
        for slot in active_slots:
            output += f"\n✅ **{slot}**"
    else:
        output += "\n⏸️ No slots are currently active."
    
    output += "\n\n---\n\n### All Slots:\n"
    for slot_id, slot_info in TIME_SLOTS.items():
        output += f"\n- **{slot_id}**: {slot_info['label']} ({slot_info['day']})"
    
    return output


# Create Gradio Interface
with gr.Blocks(title="APTI Attendance - Form Checker", theme=gr.themes.Soft()) as demo:
    gr.Markdown("""
    # 📋 APTI Attendance - Google Form Status Checker
    
    Monitor the attendance form status based on time slots.
    
    ---
    
    ## 🔌 API Usage
    
    **Endpoint:** `GET /api/status?slot=tue_930`
    
    **Available Slots:** `tue_930`, `fri_1110`, `tue_140`, `tue_1110`
    
    ---
    """)
    
    with gr.Row():
        with gr.Column(scale=1):
            gr.Markdown("### 📍 Current Status")
            current_info = gr.Markdown(value=get_current_info())
            refresh_btn = gr.Button("🔄 Refresh", variant="secondary")
            refresh_btn.click(fn=get_current_info, outputs=current_info)
        
        with gr.Column(scale=2):
            gr.Markdown("### 🔍 Check Slot Status")
            slot_dropdown = gr.Dropdown(
                choices=list(TIME_SLOTS.keys()),
                label="Select Time Slot",
                info="Choose a slot to check its status"
            )
            check_btn = gr.Button("Check Status", variant="primary")
            result_output = gr.Markdown(value="Select a slot and click 'Check Status'")
            
            check_btn.click(fn=format_slot_status, inputs=slot_dropdown, outputs=result_output)
    
    gr.Markdown("""
    ---
    
    ### ℹ️ Time Slots
    
    | Slot ID | Time | Day |
    |---------|------|-----|
    | `tue_930` | 9:30 - 11:10 AM | Tuesday |
    | `fri_1110` | 11:10 AM - 12:50 PM | Friday |
    | `tue_140` | 1:40 - 3:20 PM | Tuesday |
    | `tue_1110` | 11:10 AM - 12:50 PM | Tuesday |
    """)


# Create FastAPI app and mount Gradio
app = FastAPI()


@app.get("/api/status")
async def get_status(slot: str = Query(None, description="Time slot ID")):
    """API endpoint for checking form status"""
    if not slot:
        return JSONResponse(content={
            'error': True,
            'message': 'Missing slot parameter. Use ?slot=tue_930',
            'available_slots': list(TIME_SLOTS.keys()),
            'current_time': datetime.now(IST).isoformat()
        })
    
    result = api_check_slot(slot)
    return JSONResponse(content=result)


@app.get("/api/slots")
async def get_slots():
    """Get all available slots"""
    return JSONResponse(content={
        'slots': {k: {'label': v['label'], 'day': v['day']} for k, v in TIME_SLOTS.items()},
        'current_time': datetime.now(IST).isoformat()
    })


@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return JSONResponse(content={
        'status': 'healthy',
        'current_time': datetime.now(IST).isoformat()
    })


# Mount Gradio app
app = gr.mount_gradio_app(app, demo, path="/")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
