import os
import torch
import torchvision
import cv2
import numpy as np
from tqdm import tqdm
from pathlib import Path
from boxmot.trackers.botsort.botsort import BotSort
# from boxmot.trackers.strongsort.strongsort import StrongSort


label_map = {}
label_id_counter = [0]

# Function to generate a unique color for each track ID
def get_color(track_id):
    np.random.seed(int(track_id))
    return tuple(np.random.randint(0, 255, 3).tolist())

# Function to parse detection lines
def parse_detection(line):
    try:
        # Split only on first two spaces (label + score)
        parts = line.strip().split(maxsplit=2)
        if len(parts) < 3:
            raise ValueError("Detection line does not contain label, score, and coords.")

        label = parts[0]
        score = float(parts[1])

        # Normalize coordinates: remove brackets and commas
        coords_raw = parts[2].strip('[]').replace(',', ' ')
        coords = [int(val) for val in coords_raw.strip().split() if val.isdigit() or (val[0] == '-' and val[1:].isdigit())]

        if len(coords) != 8:
            raise ValueError(f"Expected 8 integers for 4 (x,y) points, got {len(coords)} → {coords}")

        points = np.array(coords).reshape(-1, 2)

        x_min = points[:, 0].min()
        y_min = points[:, 1].min()
        x_max = points[:, 0].max()
        y_max = points[:, 1].max()

        x = x_min
        y = y_min
        w = x_max - x_min
        h = y_max - y_min

        if label not in label_map:
            label_map[label] = label_id_counter[0]
            label_id_counter[0] += 1

        class_id = label_map.get(label, 0)  # fallback to 0 if unknown label
        return [x, y, x_max, y_max, score, class_id]

    except Exception as e:
        print(f"[⚠️ Skipped] {line.strip()}\n  ↳ Error: {e}")
        return None

# Function to get detections for a specific frame
def get_detections_for_frame(frame_name, det_dir="/datasets/eris/detections"):
    det_path = os.path.join(det_dir, os.path.splitext(frame_name)[0] + ".txt")
    if not os.path.exists(det_path):
        return []
    with open(det_path, "r") as f:
        lines = f.readlines()
    return [parse_detection(line) for line in lines]


if __name__ == "__main__":
    # Load a pre-trained Keypoint R-CNN model from torchvision
    device = torch.device('cuda:0' if torch.cuda.is_available() else 'cpu')

    # Initialize the tracker
    tracker = BotSort(
        reid_weights=Path("/weights/osnet_x0_25_market1501.pt"),
        device=device,
        half=True,
        with_reid=True
        )

    # Create a video writer
    fourcc = cv2.VideoWriter_fourcc(*'XVID')
    fps = 10
    video_size = (1920, 1080)  # Change this to your video size
    video_writer = cv2.VideoWriter(os.path.join('/data/output', "output.avi"), fourcc, fps, video_size)

    # Load images from a path
    images_path = Path('/datasets/eris/camera_front')
    images = sorted(images_path.glob('*.png'))  # Assuming images are in .jpg format

    for image_path in tqdm(images):
        # Read the image
        im = cv2.imread(str(image_path))

        # Skip if image is not found
        if im is None:
            print(f"Failed to read image: {image_path}")
            continue

        # Load detections for the current image from /data/detasets/eris/detections
        dets = get_detections_for_frame(image_path.name.split('.')[0])
    
        # Skip if no detections are found after adding to video
        if not dets:
            resize_im = cv2.resize(im, video_size)
            video_writer.write(resize_im)
            continue

        # Convert detections to a numpy array (N x (x, y, x, y, conf, cls))
        dets = np.array(dets)

        # Update tracker with detections and image
        tracks = tracker.update(dets, im)  # M x (x, y, x, y, id, conf, cls, ind)

        if len(tracks) > 0:
            inds = tracks[:, 7].astype('int')  # Get track indices as int

            # Draw bounding boxes and keypoints in the same loop
            for i, track in enumerate(tracks):
                x1, y1, x2, y2, track_id, conf, cls = track[:7].astype('int')
                color = get_color(track_id)

                # Draw bounding box with unique color
                cv2.rectangle(im, (x1, y1), (x2, y2), color, 2)

                # Add text with ID, confidence, and class
                cv2.putText(im, f'ID: {track_id}, Conf: {conf:.2f}, Class: {cls}', 
                            (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        # Save the image in /data/output path
        # cv2.imwrite(f'/data/output/{image_path.name}', im)
        resize_im = cv2.resize(im, video_size)
        video_writer.write(resize_im)

    # Release the video writer
    video_writer.release()
    