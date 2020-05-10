import setuptools

with open("README.md", "r") as f:
    long_description = f.read()

setuptools.setup(
    name="regex_fun-m-tosch",
    version="0.0.1",
    author="Maximilian Tosch",
    author_email="empty@empty.com",
    license="MIT",
    description="Fun regex tools",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/m-tosch/regex_fun",
    packages=setuptools.find_packages(exclude=["tests*"]),
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.6",
)
