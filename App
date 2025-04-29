import streamlit as st
import google.generativeai as genai
from PIL import Image, UnidentifiedImageError, ImageStat
import io
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import time
from datetime import datetime
import psutil
from fpdf import FPDF
import os

# Configure Streamlit page
st.set_page_config(page_title="AI Forensic Dashboard", layout="wide")

# Directly input the API key here
API_KEY = "AIzaSyC7E3q9YEXMh6sV0qy5lmhSVjW7bfrwnZE"

# Initialize Gemini API with the directly provided API key
genai.configure(api_key=API_KEY)

def get_gemini_response(image_data, prompt):
    """Send image and prompt to Gemini API for analysis."""
    model = genai.GenerativeModel('gemini-2.0-flash')
    try:
        response = model.generate_content([prompt, image_data])
        return response.text
    except Exception as e:
        st.error(f"Error analyzing image: {str(e)}")
        return f"Error: {str(e)}"

def input_image_setup(uploaded_file):
    """Process uploaded image for Gemini API."""
    try:
        if uploaded_file is not None:
            bytes_data = uploaded_file.getvalue()
            image = Image.open(io.BytesIO(bytes_data))
            
            # Check if the image is TIFF or other supported formats
            if image.format not in ["JPEG", "PNG", "TIFF"]:
                st.error("Unsupported file format. Please upload a .jpg, .jpeg, .png, or .tif file.")
                return None, None

            # Convert TIFF to RGB if necessary
            if image.format == "TIFF" and image.mode != "RGB":
                image = image.convert("RGB")

            image_parts = [{"mime_type": uploaded_file.type, "data": bytes_data}]
            return image, image_parts
        else:
            st.error("No file uploaded")
            return None, None
    except UnidentifiedImageError:
        st.error("Unable to process the uploaded file. Ensure it is a valid image.")
        return None, None

def create_pdf_report(image, response, analysis_mode, timestamp):
    """Create a PDF report for the analysis."""
    # Create PDF
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Arial", size=12)
    
    # Add content to PDF
    pdf.cell(200, 10, txt="AI Forensic Dashboard Analysis Report", ln=True, align="C")
    pdf.ln(10)
    pdf.cell(200, 10, txt=f"Timestamp: {timestamp}", ln=True, align="L")
    pdf.cell(200, 10, txt=f"Mode: {analysis_mode}", ln=True, align="L")
    pdf.ln(10)
    pdf.multi_cell(0, 10, txt=f"Analysis Results:\n{response}")
    
    # Add image to PDF
    pdf.ln(10)
    pdf.cell(200, 10, txt="Uploaded Image:", ln=True, align="L")
    
    # Save image temporarily
    temp_image_path = "uploaded_image.jpg"
    image.save(temp_image_path)
    pdf.image(temp_image_path, x=10, y=None, w=100)
    
    # Save the PDF to a temporary path
    pdf_path = "analysis_report.pdf"
    pdf.output(pdf_path)
    return pdf_path

def analyze_image_tampering(image):
    """Analyze image for tampering based on brightness and other features."""
    grayscale_image = image.convert("L")
    stat = ImageStat.Stat(grayscale_image)
    brightness = stat.mean[0]
    brightness_status = "Normal"
    if brightness < 50:
        brightness_status = "Low brightness detected"
    elif brightness > 200:
        brightness_status = "High brightness detected"
    tampered_status = "Image appears untampered"
    if brightness_status != "Normal":
        tampered_status = "Possible image tampering detected due to brightness issues"
    tampering_report = f"Brightness: {brightness:.2f} ({brightness_status})"
    return tampering_report, tampered_status

def main():
    st.title("AI Forensic Dashboard with Gemini Integration")
    st.markdown("Upload crime scene images (JPG, PNG, or TIFF) for real-time analysis and evidence detection.")
    st.sidebar.header("Analysis Settings")
    analysis_mode = st.sidebar.selectbox(
        "Analysis Mode",
        ["Evidence Detection", "Object Identification", "Scene Description", "Image Tampering Analysis"]
    )
    confidence_threshold = st.sidebar.slider("Confidence Threshold", 0.0, 1.0, 0.7, 0.05)
    uploaded_file = st.file_uploader("Upload Crime Scene Image", type=["jpg", "jpeg", "png", "tif", "tiff"])
    col1, col2 = st.columns([2, 1])
    with col1:
        st.subheader("Image Preview")
        if uploaded_file is not None:
            image, image_parts = input_image_setup(uploaded_file)
            if image:
                st.image(image, caption="Uploaded Crime Scene Image", use_column_width=True)
    with col2:
        st.subheader("Analysis Controls")
        analyze_button = st.button("Analyze Image")
    if uploaded_file and analyze_button:
        if image_parts is None:
            st.error("Failed to prepare the image for analysis.")
            return
        with st.spinner("Analyzing image..."):
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            response = ""
            if analysis_mode == "Image Tampering Analysis":
                report, status = analyze_image_tampering(image)
                response = f"{report}\n\nStatus: {status}"
            else:
                prompt = "Describe this image."
                response = get_gemini_response(image_parts[0], prompt)
            st.write(f"**Timestamp**: {timestamp}")
            st.write(f"**Mode**: {analysis_mode}")
            st.write(response)
            pdf_path = create_pdf_report(image, response, analysis_mode, timestamp)
            with open(pdf_path, "rb") as pdf_file:
                st.download_button(
                    label="Download Analysis Report",
                    data=pdf_file,
                    file_name="analysis_report.pdf",
                    mime="application/pdf"
                )

if __name__ == "__main__":
    main()
