import matplotlib.pyplot as plt
import numpy as np
import os

# Configuração de Estilo (Dark Mode / Tech)
plt.style.use('dark_background')
colors = ['#1f77b4', '#ff7f0e', '#2ca02c'] # Azul (Docker), Laranja (TinyGo), Verde (Rust)

def create_bar_chart(title, metrics, values, labels, filename, ylabel, unit_label=""):
    fig, ax = plt.subplots(figsize=(10, 6))
    
    y_pos = np.arange(len(labels))
    bars = ax.barh(y_pos, values, align='center', color=colors)
    
    ax.set_yticks(y_pos)
    ax.set_yticklabels(labels)
    ax.invert_yaxis()  # labels read top-to-bottom
    ax.set_xlabel(ylabel)
    ax.set_title(title, fontsize=14, fontweight='bold', pad=20)
    
    # Adicionar valores nas barras
    for i, v in enumerate(values):
        ax.text(v + (max(values)*0.01), i, f"{str(v)} {unit_label}", color='white', fontweight='bold', va='center')

    # Remover bordas desnecessárias
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['bottom'].set_color('#444444')
    ax.spines['left'].set_color('#444444')
    
    plt.tight_layout()
    plt.savefig(f"assets/{filename}", dpi=100, transparent=False)
    print(f"✅ Generated assets/{filename}")
    plt.close()

# Dados dos Benchmarks (v0.3.0)
labels = ['Docker (Native)', 'Gojinn (TinyGo)', 'Gojinn (Rust)']

# 1. Throughput
create_bar_chart(
    "Throughput (Requests/sec) - Higher is Better",
    labels,
    [14500, 5300, 6200],
    labels,
    "chart_throughput.png",
    "Requests per Second"
)

# 2. Latency Min (Sub-ms)
create_bar_chart(
    "Minimum Latency (ms) - Lower is Better",
    labels,
    [0.13, 1.17, 0.44],
    labels,
    "chart_latency.png",
    "Time (ms)",
    "ms"
)

# 3. Cold Start
create_bar_chart(
    "Cold Start Time (Avg) - Lower is Better",
    ['Docker (Container)', 'Gojinn (Sandbox)'],
    [730, 163],
    ['Docker', 'Gojinn'],
    "chart_coldstart.png",
    "Time (ms)",
    "ms"
)

# 4. Artifact Size
create_bar_chart(
    "Artifact Size (Disk) - Lower is Better",
    labels,
    [20.6, 0.28, 0.18],
    labels,
    "chart_size.png",
    "Size (MB)",
    "MB"
)